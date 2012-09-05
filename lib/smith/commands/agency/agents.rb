# -*- encoding: utf-8 -*-
module Smith
  module Commands
    class Agents < CommandBase
      def execute
        responder.value do
          # FIXME make sure that if the path doesn't exist don't blow up.
          agent_paths = Smith.agent_paths.inject([]) do |path_acc,path|
            path_acc.tap do |a|
              if path.exist?
                a << path.each_child.inject([]) do |agent_acc,p|
                  agent_acc.tap do |b|
                    b << Extlib::Inflection.camelize(p.basename('.rb')) if p.file? && p.basename('.rb').to_s.end_with?("agent")
                  end
                end.flatten
              else
                error_message = "Agent path doesn't exist: #{path}"
                responder.value(error_message)
                []
              end
            end
          end.flatten
          separator = (options[:one_column]) ? "\n" : " "
          (agent_paths.empty?) ? "" : agent_paths.sort.join(separator)
        end
      end

      private

      def options_spec
        banner "List all available agents."

        opt    :one_column, "the number of times to send the message", :short => :s
      end
    end
  end
end
