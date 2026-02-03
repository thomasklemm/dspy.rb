#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Customer Support Multi-Agent System
#
# This example demonstrates a sophisticated customer support system using multiple
# specialized agents working together. It showcases:
#
# - Multiple specialized agents (Triage, Technical, Billing, Account)
# - Custom toolsets for different operations (KB, Tickets, User Info)
# - Agent coordination and routing
# - Type-safe structured outputs with Sorbet
# - Stateful conversation handling
#
# Architecture:
# 1. CoordinatorAgent receives customer query
# 2. TriageAgent categorizes and prioritizes the request
# 3. Coordinator routes to specialized agent (Technical/Billing/Account)
# 4. Specialized agent uses tools to resolve the issue
# 5. Response is returned to the customer

require 'bundler/setup'
require 'dspy'
require 'dotenv'

# Load environment variables
Dotenv.load(File.join(File.dirname(__FILE__), '..', '..', '.env'))

# ============================================================================
# Type Definitions
# ============================================================================

# Support request categories
class SupportCategory < T::Enum
  enums do
    Technical = new('technical')
    Billing = new('billing')
    Account = new('account')
    General = new('general')
  end
end

# Priority levels
class Priority < T::Enum
  enums do
    Low = new('low')
    Medium = new('medium')
    High = new('high')
    Urgent = new('urgent')
  end
end

# Ticket status
class TicketStatus < T::Enum
  enums do
    Open = new('open')
    InProgress = new('in_progress')
    Resolved = new('resolved')
    Escalated = new('escalated')
  end
end

# Customer sentiment
class SentimentLevel < T::Enum
  enums do
    Positive = new('positive')
    Neutral = new('neutral')
    Negative = new('negative')
    Frustrated = new('frustrated')
  end
end

# Account tier
class AccountTier < T::Enum
  enums do
    Free = new('free')
    Basic = new('basic')
    Pro = new('pro')
    Enterprise = new('enterprise')
  end
end

# ============================================================================
# Data Structures
# ============================================================================

# Support ticket
class Ticket < T::Struct
  const :id, String
  const :category, SupportCategory
  const :priority, Priority
  const :status, TicketStatus
  const :customer_id, String
  const :subject, String
  const :description, String
  const :created_at, String
  const :updated_at, String
end

# User information
class UserInfo < T::Struct
  const :user_id, String
  const :email, String
  const :name, String
  const :account_tier, AccountTier
  const :account_status, String
  const :billing_status, String
  const :join_date, String
end

# Knowledge base article
class KnowledgeBaseArticle < T::Struct
  const :id, String
  const :title, String
  const :category, SupportCategory
  const :content, String
  const :helpful_count, Integer
  const :url, String
end

# Triage result
class TriageResult < T::Struct
  const :category, SupportCategory
  const :priority, Priority
  const :sentiment, SentimentLevel
  const :suggested_agent, String
  const :key_issues, T::Array[String]
end

# Agent response
class SupportResponse < T::Struct
  const :resolved, T::Boolean
  const :response_text, String
  const :actions_taken, T::Array[String]
  const :ticket_id, T.nilable(String)
  const :follow_up_needed, T::Boolean
end

# ============================================================================
# Toolsets
# ============================================================================

# Knowledge Base Toolset
class KnowledgeBaseToolset < DSPy::Tools::Toolset
  extend T::Sig

  toolset_name "knowledge_base"

  tool :search_articles, description: "Search knowledge base for articles matching a query"
  tool :get_article, description: "Get a specific article by ID"
  tool :find_solutions, description: "Find solutions for a specific problem category"

  sig { params(query: String, category: T.nilable(SupportCategory)).returns(T::Array[KnowledgeBaseArticle]) }
  def search_articles(query:, category: nil)
    # Simulate KB search
    articles = [
      KnowledgeBaseArticle.new(
        id: "kb-001",
        title: "How to reset your password",
        category: SupportCategory::Account,
        content: "To reset your password, go to Settings > Security > Reset Password...",
        helpful_count: 245,
        url: "https://support.example.com/kb-001"
      ),
      KnowledgeBaseArticle.new(
        id: "kb-002",
        title: "Understanding your bill",
        category: SupportCategory::Billing,
        content: "Your monthly bill includes: subscription fee, usage charges...",
        helpful_count: 189,
        url: "https://support.example.com/kb-002"
      ),
      KnowledgeBaseArticle.new(
        id: "kb-003",
        title: "Troubleshooting connection issues",
        category: SupportCategory::Technical,
        content: "If you're experiencing connection issues, try these steps: 1. Check your internet...",
        helpful_count: 312,
        url: "https://support.example.com/kb-003"
      ),
      KnowledgeBaseArticle.new(
        id: "kb-004",
        title: "API rate limits explained",
        category: SupportCategory::Technical,
        content: "API rate limits vary by account tier: Free (100/hr), Basic (1000/hr)...",
        helpful_count: 156,
        url: "https://support.example.com/kb-004"
      )
    ]

    filtered = category ? articles.select { |a| a.category == category } : articles
    filtered.select { |a| a.title.downcase.include?(query.downcase) || a.content.downcase.include?(query.downcase) }
  end

  sig { params(article_id: String).returns(T.nilable(KnowledgeBaseArticle)) }
  def get_article(article_id:)
    search_articles(query: "", category: nil).find { |a| a.id == article_id }
  end

  sig { params(category: SupportCategory).returns(T::Array[KnowledgeBaseArticle]) }
  def find_solutions(category:)
    search_articles(query: "", category: category).sort_by(&:helpful_count).reverse.take(3)
  end
end

# Ticket Management Toolset
class TicketToolset < DSPy::Tools::Toolset
  extend T::Sig

  toolset_name "ticket"

  tool :create_ticket, description: "Create a new support ticket"
  tool :update_ticket, description: "Update an existing ticket's status"
  tool :get_ticket, description: "Get ticket information by ID"
  tool :add_note, description: "Add a note to a ticket"

  def initialize
    super
    @tickets = {}
    @ticket_counter = 1000
  end

  sig { params(
    customer_id: String,
    category: SupportCategory,
    priority: Priority,
    subject: String,
    description: String
  ).returns(Ticket) }
  def create_ticket(customer_id:, category:, priority:, subject:, description:)
    ticket_id = "TKT-#{@ticket_counter}"
    @ticket_counter += 1

    now = Time.now.iso8601

    ticket = Ticket.new(
      id: ticket_id,
      category: category,
      priority: priority,
      status: TicketStatus::Open,
      customer_id: customer_id,
      subject: subject,
      description: description,
      created_at: now,
      updated_at: now
    )

    @tickets[ticket_id] = ticket
    ticket
  end

  sig { params(ticket_id: String, status: TicketStatus).returns(String) }
  def update_ticket(ticket_id:, status:)
    ticket = @tickets[ticket_id]
    return "Ticket not found" unless ticket

    @tickets[ticket_id] = Ticket.new(
      id: ticket.id,
      category: ticket.category,
      priority: ticket.priority,
      status: status,
      customer_id: ticket.customer_id,
      subject: ticket.subject,
      description: ticket.description,
      created_at: ticket.created_at,
      updated_at: Time.now.iso8601
    )

    "Ticket #{ticket_id} updated to #{status.serialize}"
  end

  sig { params(ticket_id: String).returns(T.nilable(Ticket)) }
  def get_ticket(ticket_id:)
    @tickets[ticket_id]
  end

  sig { params(ticket_id: String, note: String).returns(String) }
  def add_note(ticket_id:, note:)
    return "Ticket not found" unless @tickets[ticket_id]
    "Note added to #{ticket_id}: #{note}"
  end
end

# User Information Toolset
class UserInfoToolset < DSPy::Tools::Toolset
  extend T::Sig

  toolset_name "user_info"

  tool :get_user, description: "Get user information by user ID"
  tool :check_billing_status, description: "Check user's billing status"
  tool :get_account_tier, description: "Get user's account tier information"

  sig { params(user_id: String).returns(T.nilable(UserInfo)) }
  def get_user(user_id:)
    # Simulate user database
    users = {
      "user-001" => UserInfo.new(
        user_id: "user-001",
        email: "alice@example.com",
        name: "Alice Johnson",
        account_tier: AccountTier::Pro,
        account_status: "active",
        billing_status: "current",
        join_date: "2023-01-15"
      ),
      "user-002" => UserInfo.new(
        user_id: "user-002",
        email: "bob@example.com",
        name: "Bob Smith",
        account_tier: AccountTier::Basic,
        account_status: "active",
        billing_status: "payment_failed",
        join_date: "2023-06-20"
      ),
      "user-003" => UserInfo.new(
        user_id: "user-003",
        email: "carol@example.com",
        name: "Carol Williams",
        account_tier: AccountTier::Enterprise,
        account_status: "active",
        billing_status: "current",
        join_date: "2022-03-10"
      )
    }

    users[user_id]
  end

  sig { params(user_id: String).returns(String) }
  def check_billing_status(user_id:)
    user = get_user(user_id: user_id)
    return "User not found" unless user

    "Billing status for #{user.name}: #{user.billing_status}, Account tier: #{user.account_tier.serialize}"
  end

  sig { params(user_id: String).returns(String) }
  def get_account_tier(user_id:)
    user = get_user(user_id: user_id)
    return "User not found" unless user

    tier_info = {
      'free' => 'Free tier: Basic features, 100 API calls/hour',
      'basic' => 'Basic tier: Standard features, 1000 API calls/hour, Email support',
      'pro' => 'Pro tier: Advanced features, 10000 API calls/hour, Priority support',
      'enterprise' => 'Enterprise tier: All features, Unlimited API calls, 24/7 support'
    }

    tier_info[user.account_tier.serialize] || "Unknown tier"
  end
end

# ============================================================================
# Agent Signatures
# ============================================================================

# Triage agent signature
class TriageSignature < DSPy::Signature
  description "Analyze customer support request and categorize it for routing to appropriate agent"

  input do
    const :customer_query, String
    const :user_id, String
  end

  output do
    const :triage_result, TriageResult
  end
end

# Technical support agent signature
class TechnicalSupportSignature < DSPy::Signature
  description "Resolve technical support issues using available tools and knowledge base"

  input do
    const :issue_description, String
    const :user_id, String
    const :priority, Priority
  end

  output do
    const :support_response, SupportResponse
  end
end

# Billing agent signature
class BillingSignature < DSPy::Signature
  description "Handle billing inquiries and payment issues"

  input do
    const :billing_query, String
    const :user_id, String
    const :priority, Priority
  end

  output do
    const :support_response, SupportResponse
  end
end

# Account agent signature
class AccountSignature < DSPy::Signature
  description "Handle account-related requests like password resets and settings"

  input do
    const :account_query, String
    const :user_id, String
    const :priority, Priority
  end

  output do
    const :support_response, SupportResponse
  end
end

# ============================================================================
# Specialized Agents
# ============================================================================

# Triage Agent - categorizes and routes requests
class TriageAgent < DSPy::Module
  def initialize
    super
    @predictor = DSPy::ChainOfThought.new(TriageSignature)
  end

  def forward_untyped(**inputs)
    @predictor.call(
      customer_query: inputs[:customer_query],
      user_id: inputs[:user_id]
    )
  end
end

# Technical Support Agent
class TechnicalSupportAgent < DSPy::Module
  def initialize
    super

    # Combine KB and ticket tools
    kb_tools = KnowledgeBaseToolset.to_tools
    ticket_tools = TicketToolset.to_tools

    @agent = DSPy::ReAct.new(
      TechnicalSupportSignature,
      tools: kb_tools + ticket_tools,
      max_iterations: 6
    )
  end

  def forward_untyped(**inputs)
    @agent.call(
      issue_description: inputs[:issue_description],
      user_id: inputs[:user_id],
      priority: inputs[:priority]
    )
  end
end

# Billing Agent
class BillingAgent < DSPy::Module
  def initialize
    super

    # Combine user info, KB, and ticket tools
    user_tools = UserInfoToolset.to_tools
    kb_tools = KnowledgeBaseToolset.to_tools
    ticket_tools = TicketToolset.to_tools

    @agent = DSPy::ReAct.new(
      BillingSignature,
      tools: user_tools + kb_tools + ticket_tools,
      max_iterations: 6
    )
  end

  def forward_untyped(**inputs)
    @agent.call(
      billing_query: inputs[:billing_query],
      user_id: inputs[:user_id],
      priority: inputs[:priority]
    )
  end
end

# Account Agent
class AccountAgent < DSPy::Module
  def initialize
    super

    # Combine user info, KB, and ticket tools
    user_tools = UserInfoToolset.to_tools
    kb_tools = KnowledgeBaseToolset.to_tools
    ticket_tools = TicketToolset.to_tools

    @agent = DSPy::ReAct.new(
      AccountSignature,
      tools: user_tools + kb_tools + ticket_tools,
      max_iterations: 6
    )
  end

  def forward_untyped(**inputs)
    @agent.call(
      account_query: inputs[:account_query],
      user_id: inputs[:user_id],
      priority: inputs[:priority]
    )
  end
end

# ============================================================================
# Coordinator Agent
# ============================================================================

# Coordinator that routes to specialized agents
class CustomerSupportCoordinator < DSPy::Module
  def initialize
    super

    @triage_agent = TriageAgent.new
    @technical_agent = TechnicalSupportAgent.new
    @billing_agent = BillingAgent.new
    @account_agent = AccountAgent.new
  end

  def handle_request(customer_query:, user_id:)
    puts "\n" + "=" * 80
    puts "🎯 CUSTOMER SUPPORT REQUEST"
    puts "=" * 80
    puts "User ID: #{user_id}"
    puts "Query: #{customer_query}"
    puts "-" * 80

    # Step 1: Triage the request
    puts "\n📋 STEP 1: Triaging request..."
    triage_result = @triage_agent.call(
      customer_query: customer_query,
      user_id: user_id
    )

    puts "\n✅ Triage Complete:"
    puts "  Category: #{triage_result.triage_result.category.serialize}"
    puts "  Priority: #{triage_result.triage_result.priority.serialize}"
    puts "  Sentiment: #{triage_result.triage_result.sentiment.serialize}"
    puts "  Suggested Agent: #{triage_result.triage_result.suggested_agent}"
    puts "  Key Issues: #{triage_result.triage_result.key_issues.join(', ')}"

    # Step 2: Route to appropriate agent
    puts "\n🔀 STEP 2: Routing to #{triage_result.triage_result.suggested_agent}..."

    response = case triage_result.triage_result.category
    when SupportCategory::Technical
      @technical_agent.call(
        issue_description: customer_query,
        user_id: user_id,
        priority: triage_result.triage_result.priority
      )
    when SupportCategory::Billing
      @billing_agent.call(
        billing_query: customer_query,
        user_id: user_id,
        priority: triage_result.triage_result.priority
      )
    when SupportCategory::Account
      @account_agent.call(
        account_query: customer_query,
        user_id: user_id,
        priority: triage_result.triage_result.priority
      )
    else
      # Default to account agent for general queries
      @account_agent.call(
        account_query: customer_query,
        user_id: user_id,
        priority: triage_result.triage_result.priority
      )
    end

    # Step 3: Display results
    puts "\n✅ RESOLUTION:"
    puts "  Status: #{response.support_response.resolved ? '✓ Resolved' : '⚠ Needs Follow-up'}"
    puts "  Ticket ID: #{response.support_response.ticket_id || 'N/A'}"
    puts "\n💬 Response to Customer:"
    puts "  #{response.support_response.response_text}"
    puts "\n🔧 Actions Taken:"
    response.support_response.actions_taken.each do |action|
      puts "  • #{action}"
    end
    puts "\n📌 Follow-up Required: #{response.support_response.follow_up_needed ? 'Yes' : 'No'}"
    puts "\n" + "=" * 80

    response
  end

  def forward_untyped(**inputs)
    handle_request(
      customer_query: inputs[:customer_query],
      user_id: inputs[:user_id]
    )
  end
end

# ============================================================================
# Main Execution
# ============================================================================

if __FILE__ == $0
  # Check for API key
  unless ENV['ANTHROPIC_API_KEY'] || ENV['OPENAI_API_KEY']
    puts "Error: Please set ANTHROPIC_API_KEY or OPENAI_API_KEY environment variable"
    exit 1
  end

  # Configure DSPy
  DSPy.configure do |config|
    if ENV['ANTHROPIC_API_KEY']
      config.lm = DSPy::LM.new(
        'anthropic/claude-3-5-sonnet-20241022',
        api_key: ENV['ANTHROPIC_API_KEY']
      )
    else
      config.lm = DSPy::LM.new(
        'openai/gpt-4o-mini',
        api_key: ENV['OPENAI_API_KEY']
      )
    end
  end

  # Create coordinator
  coordinator = CustomerSupportCoordinator.new

  puts "\n🤖 Customer Support Multi-Agent System"
  puts "Demonstrating intelligent routing and specialized agents\n"

  # Example 1: Technical Issue
  coordinator.handle_request(
    customer_query: "My API calls are failing with a 429 rate limit error. I'm on the Pro plan and shouldn't be hitting limits.",
    user_id: "user-001"
  )

  sleep 1

  # Example 2: Billing Issue
  coordinator.handle_request(
    customer_query: "My payment failed but I don't understand why. Can you help me understand my bill?",
    user_id: "user-002"
  )

  sleep 1

  # Example 3: Account Issue
  coordinator.handle_request(
    customer_query: "I forgot my password and need to reset it. How do I do that?",
    user_id: "user-003"
  )

  sleep 1

  # Example 4: Complex multi-category issue
  coordinator.handle_request(
    customer_query: "I'm having connection problems and I think it might be related to my billing status. My account seems to be acting weird.",
    user_id: "user-002"
  )

  puts "\n✨ All support requests completed!"
end
