---
layout: blog
order: 9
title: "Raw Chat API for Benchmarking and Migration"
date: 2025-07-23
description: "Learn how to use DSPy.rb's raw_chat API for benchmarking monolithic prompts and migrating to modular implementations"
tags: [api, benchmarking, migration, observability]
excerpt: |
  The raw_chat API lets you run existing prompts through DSPy's observability system to compare token usage and performance against modular implementations.
permalink: /blog/raw-chat-api/
canonical_url: "https://vicentereig.github.io/dspy.rb/blog/articles/raw-chat-api/"
image: /images/og/raw-chat-api.png
---

DSPy.rb 0.12.0 introduces the `raw_chat` API for benchmarking existing prompts and migrating to DSPy's modular approach.

## The Problem

Many teams have existing prompts they want to compare against DSPy modules. Without running both through the same observability system, you can't get accurate comparisons.

The `raw_chat` API lets you:
- Run existing prompts through DSPy's observability system
- Compare token usage between monolithic and modular approaches
- Measure performance across different providers
- Make data-driven migration decisions

## API Overview

The `raw_chat` method provides a direct interface to language models without DSPy's structured output features:

```ruby
# Initialize a language model
lm = DSPy::LM.new('openai/gpt-4o-mini', api_key: ENV['OPENAI_API_KEY'])

# Array format
response = lm.raw_chat([
  { role: 'system', content: 'You are a helpful assistant.' },
  { role: 'user', content: 'What is the capital of France?' }
])

# DSL format for cleaner syntax
response = lm.raw_chat do |m|
  m.system "You are a helpful assistant."
  m.user "What is the capital of France?"
end
```

## Key Features

### 1. Full Instrumentation Support

Unlike bypassing DSPy entirely, `raw_chat` emits all standard log events with span tracking:

```ruby
# These events are emitted for raw_chat:
# - lm.tokens (with accurate token counts)
#
# NOT emitted:
# - parser-specific events (since there's no JSON parsing)
```

### 2. Message Builder DSL

The DSL provides a clean way to construct conversations:

```ruby
lm.raw_chat do |m|
  m.user "My name is Alice"
  m.assistant "Nice to meet you, Alice!"
  m.user "What's my name?"
end
```

### 3. Streaming Support

Stream responses with a block:

```ruby
lm.raw_chat(messages) do |chunk|
  print chunk
end
```

## Real-World Example: Changelog Generation

Here's how a team might compare their existing changelog generator with a DSPy implementation:

```ruby
# Legacy monolithic prompt
LEGACY_PROMPT = <<~PROMPT
  You are an expert changelog generator. Given git commits:
  1. Parse each commit type and description
  2. Group by type (feat, fix, chore, etc.)
  3. Generate user-friendly descriptions
  4. Format as markdown
  5. Highlight breaking changes
  Be concise but informative.
PROMPT

# Configure logging to capture data
require 'tempfile'
log_file = Tempfile.new('dspy_benchmark')

DSPy.configure do |config|
  config.logger = Dry.Logger(:dspy, formatter: :json) do |logger|
    logger.add_backend(stream: log_file)
  end
end

# Benchmark legacy approach
legacy_result = lm.raw_chat do |m|
  m.system LEGACY_PROMPT
  m.user commits.join("\n")
end

# Extract legacy tokens
log_file.rewind
events = log_file.readlines.map { |line| JSON.parse(line) }
legacy_tokens = events.find { |e| e["event"] == 'llm.generate' }

# Clear log and benchmark modular approach
log_file.truncate(0)
log_file.rewind
generator = DSPy::ChainOfThought.new(ChangelogSignature)
modular_result = generator.forward(commits: commits)

# Extract modular tokens
log_file.rewind
events = log_file.readlines.map { |line| JSON.parse(line) }
modular_tokens = events.find { |e| e["event"] == 'llm.generate' }

# Compare results
puts "Legacy: #{legacy_tokens["gen_ai.usage.total_tokens"]} tokens"
puts "Modular: #{modular_tokens["gen_ai.usage.total_tokens"]} tokens"
puts "Reduction: #{((1 - modular_tokens["gen_ai.usage.total_tokens"].to_f / legacy_tokens["gen_ai.usage.total_tokens"]) * 100).round(2)}%"
```

## Integration with Observability

`raw_chat` uses the same observability system as regular DSPy calls:

```ruby
# Configure observability
DSPy.configure do |config|
  config.logger = Dry.Logger(:dspy, formatter: :json) do |logger|
    logger.add_backend(stream: "/var/log/dspy/production.log")
  end
end

# Both calls are tracked identically
lm.raw_chat([{ role: 'user', content: 'Hello' }])
predictor.forward(input: 'Hello')
```

## Migration Strategy

Use `raw_chat` for phased migration:

### Phase 1: Baseline
```ruby
# Measure existing prompt performance
baseline = benchmark_with_raw_chat(LEGACY_PROMPT, test_dataset)
```

### Phase 2: Prototype
```ruby
# Build modular version
class ModularImplementation < DSPy::Module
  # ...
end
```

### Phase 3: Compare
```ruby
# Run side-by-side comparison
results = compare_approaches(baseline, ModularImplementation.new)
```

### Phase 4: Migrate
```ruby
# Deploy when metrics improve
if results[:modular][:tokens] < results[:legacy][:tokens] * 0.9
  deploy_modular_version
end
```

## Implementation Details

`raw_chat`:

1. **Bypasses JSON parsing** - Returns raw strings
2. **Skips retry strategies** - No structured output validation
3. **Direct adapter calls** - Minimal overhead
4. **Preserves observability** - Full span tracking and logging

This gives you fair comparisons with full monitoring.

## Best Practices

1. **Use identical test data** for both approaches
2. **Run multiple times** to account for variance
3. **Check quality**, not just token count
4. **Start small** with non-critical prompts
5. **Track production metrics** after migration

## Summary

The `raw_chat` API helps you compare existing prompts with DSPy modules using the same observability system. This lets you make informed decisions about migration based on actual data, not guesswork.

---

*See the [benchmarking guide](/docs/optimization/benchmarking-raw-prompts/) for detailed examples.*
