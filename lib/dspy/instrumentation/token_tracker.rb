# frozen_string_literal: true

module DSPy
  module Instrumentation
    # Utility for extracting token usage from different LM adapters
    # Uses actual token counts from API responses for accuracy
    module TokenTracker
      extend self

      # Extract actual token usage from API responses
      def extract_token_usage(response, provider)
        case provider.to_s.downcase
        when 'openai'
          extract_openai_tokens(response)
        when 'anthropic'
          extract_anthropic_tokens(response)
        else
          {} # No token information for other providers
        end
      end

      private

      def extract_openai_tokens(response)
        return {} unless response&.usage

        usage = response.usage
        return {} unless usage.is_a?(Hash)
        
        {
          input_tokens: usage[:prompt_tokens] || usage['prompt_tokens'],
          output_tokens: usage[:completion_tokens] || usage['completion_tokens'],
          total_tokens: usage[:total_tokens] || usage['total_tokens']
        }
      end

      def extract_anthropic_tokens(response)
        return {} unless response&.usage

        usage = response.usage
        return {} unless usage.is_a?(Hash)
        
        input_tokens = usage[:input_tokens] || usage['input_tokens'] || 0
        output_tokens = usage[:output_tokens] || usage['output_tokens'] || 0
        
        {
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          total_tokens: input_tokens + output_tokens
        }
      end
    end
  end
end
