# Customer Support Multi-Agent System

A comprehensive example demonstrating how to build a sophisticated customer support system using multiple specialized agents working together in DSPy.rb.

## Overview

This example showcases a production-ready pattern for building multi-agent systems where different agents handle different types of customer requests. The system intelligently routes requests to the appropriate specialist based on content analysis.

## Architecture

```
Customer Query
     ↓
CoordinatorAgent
     ↓
TriageAgent (Analyzes & Categorizes)
     ↓
     ├─→ TechnicalSupportAgent
     ├─→ BillingAgent
     └─→ AccountAgent (also handles General queries)
```

## Key Components

### 1. **Type System**

The example uses Sorbet enums and structs for type-safe operations:

- **Enums**: `SupportCategory`, `Priority`, `TicketStatus`, `SentimentLevel`, `AccountTier`
- **Data Structures**: `Ticket`, `UserInfo`, `KnowledgeBaseArticle`, `TriageResult`, `SupportResponse`

### 2. **Toolsets**

Three specialized toolsets provide different capabilities to agents:

#### KnowledgeBaseToolset
- `search_articles(query:, category:)` - Search KB articles
- `get_article(article_id:)` - Retrieve specific article
- `find_solutions(category:)` - Find top solutions by category

#### TicketToolset
- `create_ticket(...)` - Create new support ticket
- `update_ticket(ticket_id:, status:)` - Update ticket status
- `get_ticket(ticket_id:)` - Retrieve ticket information
- `add_note(ticket_id:, note:)` - Add notes to tickets

#### UserInfoToolset
- `get_user(user_id:)` - Get user account information
- `check_billing_status(user_id:)` - Check billing status
- `get_account_tier(user_id:)` - Get tier details

### 3. **Specialized Agents**

#### TriageAgent
Uses `ChainOfThought` to analyze customer queries and determine:
- Support category (Technical, Billing, Account, General)
- Priority level (Low, Medium, High, Urgent)
- Customer sentiment (Positive, Neutral, Negative, Frustrated)
- Which specialized agent should handle the request
- Key issues identified in the query

#### TechnicalSupportAgent
Uses `ReAct` with KB and ticket tools to:
- Search knowledge base for technical solutions
- Create and manage technical support tickets
- Resolve API issues, connection problems, etc.

#### BillingAgent
Uses `ReAct` with user info, KB, and ticket tools to:
- Check user billing status
- Explain billing charges
- Handle payment failures
- Create billing-related tickets

#### AccountAgent
Uses `ReAct` with user info, KB, and ticket tools to:
- Help with password resets
- Manage account settings
- Handle account-related queries
- Serve as fallback for general support queries

### 4. **CoordinatorAgent**

Orchestrates the entire support flow:
1. Receives customer query
2. Calls TriageAgent to categorize
3. Routes to appropriate specialized agent
4. Collects and formats response
5. Returns structured result

## Running the Example

```bash
# Set up your API key
export ANTHROPIC_API_KEY=your-api-key
# or
export OPENAI_API_KEY=your-api-key

# Run the example
ruby examples/customer-support-multi-agent/main.rb
```

## Example Scenarios

The example demonstrates four different support scenarios:

### 1. Technical Issue (API Rate Limits)
```
Query: "My API calls are failing with a 429 rate limit error. I'm on the Pro plan."
→ Routes to: TechnicalSupportAgent
→ Actions: Searches KB, checks account tier, provides solution
```

### 2. Billing Issue (Payment Failure)
```
Query: "My payment failed but I don't understand why."
→ Routes to: BillingAgent
→ Actions: Checks billing status, explains charges, offers solutions
```

### 3. Account Issue (Password Reset)
```
Query: "I forgot my password and need to reset it."
→ Routes to: AccountAgent
→ Actions: Searches KB for reset instructions, provides step-by-step guide
```

### 4. Multi-Category Issue
```
Query: "Connection problems + billing status concerns + account issues"
→ Routes to: Most relevant agent based on primary concern
→ Actions: Handles complex multi-faceted issues
```

## Key Features Demonstrated

### 1. **Multi-Agent Coordination**
Shows how to compose multiple specialized agents into a cohesive system with intelligent routing.

### 2. **Tool Composition**
Demonstrates how different agents can use different combinations of tools based on their specialization.

### 3. **Type Safety**
Uses Sorbet throughout for compile-time type checking and better IDE support.

### 4. **Structured Outputs**
All agents return structured data (not strings), making responses easy to process and store.

### 5. **Stateful Operations**
TicketToolset maintains state across operations, showing how to build stateful agents.

### 6. **Real-World Patterns**
Implements patterns you'd see in production customer support systems:
- Triage and routing
- Knowledge base integration
- Ticket management
- User context awareness
- Priority handling
- Sentiment analysis

## Testing

Tests are located in `spec/examples/customer_support_multi_agent_spec.rb`:

```bash
# Run the tests
bundle exec rspec spec/examples/customer_support_multi_agent_spec.rb
```

Tests verify:
- Toolset functionality (KB search, ticket creation, user info retrieval)
- Agent initialization and tool configuration
- Type safety of all data structures
- Integration flows (requires VCR cassettes)

## Extending This Example

### Adding New Agent Types
```ruby
class RefundAgent < DSPy::Module
  def initialize
    super
    # Define tools and signature
  end
end

# Add to coordinator routing logic
```

### Adding New Tools
```ruby
class EmailToolset < DSPy::Tools::Toolset
  toolset_name "email"

  tool :send_email, description: "Send email to customer"

  sig { params(to: String, subject: String, body: String).returns(String) }
  def send_email(to:, subject:, body:)
    # Implementation
  end
end
```

### Customizing Triage Logic
Modify `TriageSignature` to include additional classification dimensions:
- Language detection
- Urgency keywords
- Customer history
- Time-based routing

## Production Considerations

### 1. **Persistence**
In production, replace the in-memory data structures with:
- Database-backed ticket storage
- Redis for session management
- External KB systems

### 2. **Observability**
Add DSPy's observability features:
```ruby
DSPy::Observability.configure!
# Traces all agent interactions to Langfuse
```

### 3. **Error Handling**
Add retry logic, fallback responses, and error recovery:
```ruby
begin
  response = agent.call(...)
rescue DSPy::ReAct::MaxIterationsError => e
  # Handle gracefully
end
```

### 4. **Scalability**
- Run agents in parallel where possible
- Cache KB articles
- Load balance across multiple LLM endpoints
- Implement rate limiting

### 5. **Security**
- Validate user_id before operations
- Sanitize inputs
- Log all actions for audit
- Implement proper authentication

## Learn More

- [Toolsets Documentation](../../docs/src/core-concepts/toolsets.md)
- [Stateful Agents](../../docs/src/advanced/stateful-agents.md)
- [ReAct Agent Pattern](../../docs/src/_articles/react-agent-tutorial.md)
- [Multi-Agent Systems](../../docs/src/advanced/pipelines.md)

## License

MIT License - see LICENSE file for details
