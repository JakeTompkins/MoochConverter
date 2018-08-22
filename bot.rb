require 'redd'
require 'redis'
require 'json'

TIME_WORDS = {
    year: 36.5,
    month: 3.05,
    week: 0.7,
    day: 0.1,
    hour: 0.00416666,
    minutes: 0.000069444,
    second: 0.000001157
}

MOOCH_WORDS = {
    mooch: 1,
    decimooch: 0.1,
    centimooch: 0.01,
    milimooch: 0.001,
    micromooch: 0.000001,
    nanomooch: 0.000000001
}

class Bot
  def initialize(options)
    @session = Redd.it(
      user_agent: 'TimeToMooch (by /u/yuanlairuci)',
      client_id: options[:client_id],
      secret: options[:secret],
      username: options[:username],
      password: options[:password]
    )

    @r = Redis.new
  end

  def get_time_phrases(string)
      string.downcase!
      regex = /\d+\s(?:#{TIME_WORDS.keys.join("|")})s?/
      string.scan(regex)
  end

  def time_to_mooches(time_phrase)
      multiplier = time_phrase.match(/\d+/)[0]
      time_word = time_phrase.sub(multiplier + ' ', '').sub(/s$/, '')

      p multiplier
      p time_word

      mooches = multiplier.to_i * TIME_WORDS[time_word.to_sym]
  end

  def mooches_to_fancy_mooches(mooches)
    highest_value = ['',0]

    MOOCH_WORDS.each do |mooch_word, value|
        if mooches >= value && value > highest_value[1]
            highest_value = [mooch_word, value]
        end
    end

    mooch_value = (mooches / highest_value[1]).round(2)
    return "#{mooch_value} #{highest_value[0]}#{mooch_value > 1 ? 'es' : ''}"
  end

  def construct_message(time_phrases)
    message = ""

    time_phrases.each do |tp|
        mooches = time_to_mooches(tp)
        fancy_mooches = mooches_to_fancy_mooches(mooches)
        message += "#{tp} = #{fancy_mooches}\n"
    end

    message
  end
  

  def run
    while true
        commented = @r.get("commented") || []
        commented = JSON.parse(commented) unless commented.empty?
        puts "Searching comments...."
        comments = @session.subreddit('politics').comments
        comments.each do |comment|
            tp = get_time_phrases(comment.body)
            unless tp.empty?
                message = construct_message(tp)
                unless commented.include?(comment.id) || comment.author.name == "TimeToMooch"
                    comment.reply(message) 
                    commented.push(comment.id)
                    puts "Replied to \n\n#{comment.body} \n\nwith \n\n#{message}"
                end
            end
        end
        puts "Sleeping for 15 seconds...."
        sleep(15)
    end
    at_exit do
        @r.set("commented", JSON.generate(commented))
    end
  end
end