require 'readline'
require 'engine'
require 'pry'
require 'character_trainer/cli_base'
require 'analects'
require 'rainbow'
require 'rainbow/ext/string'

module CharacterTrainer
  Analects = ::Analects::Library.new
  CEDICT   = Analects.cedict.inject({}) {|acc, cedict| (acc[cedict.first] ||= []) << cedict ; acc}
  HSK      = Analects.hsk
  CHISE    = Analects.chise_ids

  def self.run
    CLI.new.readline_loop
  end

  class Card < Struct.new(:char, :index, :notes, :optional)
    def hsk
      HSK.select {|hsk| hsk.traditional =~ /#{char}/}
    end

    def cedicts
      CEDICT[char]
    end

    def optional
      super || self.optional=[]
    end

    def notes
      super || self.notes=[]
    end

    def check!(input_pinyins)
      input_pinyins.all? {|ip| pinyins.include? ip } &&
        pinyins.all? {|py| input_pinyins.include?(py) || optional.include?(py) }
    end

    def pinyins
      cedicts.map {|_,_,py| py}.map(&:downcase).uniq.sort
    end
  end

  class App
    extend Forwardable
    DATA_FILE = Pathname('~').expand_path.join('.character_trainer')

    attr_reader :deck, :current_card, :previous
    def_delegators :deck, :new_cards
    def_delegators :card_data, :char, :index, :pinyins, :cedicts, :notes, :optional

    def initialize
      @current_card = nil
    end

    def card_data
      current_card.data
    end

    def load!
      @deck = Engine::Deck.new(YAML.load(DATA_FILE.read))
    end

    def save!
      File.write DATA_FILE, YAML.dump(deck.to_a)
    end

    def rate!(n)
      rated = current_card.rate(n)
      @deck = deck.update_card(current_card, rated)
      @current_card = rated
      save!
    end

    def check_input!(input)
      if card_data.check!(input)
        rate! 3
        display_card!
        next_card!
        @last_correct = true
      else
        rate! 0
        display_card!
        next_card!
        @last_correct = false
      end
    end

    def next_card!
      @previous = @current_card
      @current_card = expired_cards.first || next_new_card
      binding.pry if current_card.nil?
    end

    def add_note!(note)
      card_data.notes << note
      save!
    end

    def mark_as_optional!(pinyins)
      optional.concat pinyins
      save!
    end

    def back!
      @previous, @current_card = current_card, previous
      binding.pry if current_card.nil?
    end

    def goto!(char)
      @previous, @current_card = @current_card, deck.detect {|card| card.data.char == char.strip}
    end

    def display_card!
      cedicts.each do |args|
        print args.first
        print " (#{args[1]})" if args[0] != args[1]
        puts  " #{args[2]}"
        puts args.last.split('/').reject(&:empty?).map{|s| "- #{s}"}
      end
      puts notes if notes
    end

    def next_new_card
      new_cards.sample(10).min {|a,b| a.data.index <=> b.data.index }
    end

    def expired_cards
      deck.expired_cards(Time.now)
    end

    def prompt
      "#{expired_cards.count} #{char} #{expected_pinyins_count if expected_pinyins_count > 1}> ".foreground(@last_correct.nil? ? :blue : @last_correct ? :green : :red)
    end

    def expected_pinyins_count
      (pinyins - optional).count
    end

    def stats
      ("(%.1f%%) " % (100*(Float(deck.count - new_cards.count)/deck.count))) +
        "#{new_cards.count} new cards, #{expired_cards.count} expired. #{deck.count} total.\n"+
        "#{char} (#{index}) : #{current_card.factor} factor #{current_card.interval} interval\n" +
        "  1 hr    #{deck.expired_cards(Time.now + 60*60).count}\n" +
        " 12 hr    #{deck.expired_cards(Time.now + 12*60*60).count}\n" +
        "  1 day   #{deck.expired_cards(Time.now + 24*60*60).count}\n" +
        "  4 days  #{deck.expired_cards(Time.now + 4*24*60*60).count}\n" +
        "  1 week  #{deck.expired_cards(Time.now + 7*24*60*60).count}\n" +
        "  2 weeks #{deck.expired_cards(Time.now + 14*24*60*60).count}\n" +
        "  total   #{deck.expired_cards(Time.now + 2**50).count}"
    end
  end

  class CLI < CLIBase
    attr_reader :app

    def initialize
      @app = App.new
      @app.load!
      @app.next_card!
      puts @app.stats
    end

    on /^back/, "Go a card back" do
      app.back!
    end

    on /^skip/, "Skip this card/character" do
      app.next_card!
    end

    on /^cedict/, "Show combinations" do
      puts CEDICT.select {|tr, _,_,_| tr =~ /#{app.char}/}.map{|*a| a.join("\t")}
    end

    on /^hsk/, "Show HSK vocab" do
      puts app.card_data.hsk.map{|hsk| [hsk.level, *hsk.cedict.first] }.map{|*a| a.join("\t")}
    end

    on /^chise/, "Show character composition" do
      puts CHISE.select {|_,ch,_| ch == app.card_data.char }.map {|l| l.drop(1).join(": ")}
    end

    on /^hsk/, "Show HSK vocab" do
      puts app.card_data.hsk.map{|hsk| [hsk.level, *hsk.cedict.first] }.map{|*a| a.join("\t")}
    end

    on /^pry/, "Open a pry console" do
      app.pry
    end

    on /^his/, "Show history" do
      p app.current_card.data_points.map(&:rating)
    end

    on /^inspect/, "Show detailed card info" do
      app.deck.reject(&:new?).sort_by {|card| card.expired_for_seconds(Time.now) }.each do |card|
        puts [card.data.char, card.iteration, card.streak, card.factor, card.interval].join("\t")
      end
    end

    on /^note /, "Show the card's translations" do |input|
      app.add_note! input.gsub(/^note /,'').strip
    end

    on /^goto /, "Skip to a specific character" do |input|
      app.goto! input.gsub(/^goto /,'').strip
    end

    on /^optional /, "Mark certain pinyin as optional to remember" do |input|
      app.mark_as_optional! input.gsub(/^optional /,'').split(',').map(&:strip)
    end

    on /[0-9]/, "pinyin answer" do |input|
      app.check_input!(input.split(',').map(&:strip))
    end

    on /^h|help|\?/, "Show help" do
      commands.each do |command, description, _|
        puts [command.inspect, description].join("\t")
      end
    end

    on /^s|stats/, "Show deck statistics" do
      puts app.stats
    end

    on /^d|display/, "Show the card's translations" do
      app.display_card!
    end

    def prompt
      @app.prompt
    end
  end

end
