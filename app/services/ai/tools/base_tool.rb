# app/services/ai/tools/base_tool.rb

module Ai
  module Tools
    class BaseTool
      def success(data:, message: nil)
        {
          tool: tool_name,
          status: "success",
          data: data,
          message: message
        }
      end

      def error(message:, data: {})
        {
          tool: tool_name,
          status: "error",
          data: data,
          message: message
        }
      end

      def tool_name
        self.class.name.demodulize.underscore
      end
    end
  end
end
