module CharacterTrainer
  class CLIBase
    def self.commands
      @commands ||= []
    end

    def commands ; self.class.commands end

    def self.on(command, description, &blk)
      commands << [command, description, blk]
    end

    def readline_loop
      loop do
        input = Readline.readline(prompt, true)
        exit unless input
        commands.each do |command, _, blk|
          if command === input
            if blk.arity > 0
              instance_exec(input, &blk)
            else
              instance_eval(&blk)
            end
            break
          end
        end
      end
    end
  end
end
