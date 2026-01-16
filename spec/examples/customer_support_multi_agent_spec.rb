require 'spec_helper'
require_relative '../../examples/customer-support-multi-agent/main'

RSpec.describe 'Customer Support Multi-Agent System' do
  # ============================================================================
  # Toolset Tests
  # ============================================================================

  describe KnowledgeBaseToolset do
    let(:toolset) { described_class.new }

    describe '#search_articles' do
      it 'searches articles by query' do
        results = toolset.search_articles(query: 'password', category: nil)
        expect(results).to be_an(Array)
        expect(results.first).to be_a(KnowledgeBaseArticle)
        expect(results.map(&:title)).to include('How to reset your password')
      end

      it 'filters articles by category' do
        results = toolset.search_articles(query: '', category: SupportCategory::Technical)
        expect(results.all? { |a| a.category == SupportCategory::Technical }).to be true
      end

      it 'returns empty array when no matches found' do
        results = toolset.search_articles(query: 'nonexistent-query-xyz', category: nil)
        expect(results).to eq([])
      end
    end

    describe '#get_article' do
      it 'retrieves article by ID' do
        article = toolset.get_article(article_id: 'kb-001')
        expect(article).to be_a(KnowledgeBaseArticle)
        expect(article.id).to eq('kb-001')
      end

      it 'returns nil for non-existent article' do
        article = toolset.get_article(article_id: 'kb-999')
        expect(article).to be_nil
      end
    end

    describe '#find_solutions' do
      it 'returns top solutions for a category' do
        results = toolset.find_solutions(category: SupportCategory::Technical)
        expect(results).to be_an(Array)
        expect(results.length).to be <= 3
        expect(results.first.helpful_count).to be >= results.last.helpful_count
      end
    end

    describe '.to_tools' do
      it 'generates tools for all exposed methods' do
        tools = described_class.to_tools
        tool_names = tools.map(&:name)

        expect(tool_names).to include('knowledge_base_search_articles')
        expect(tool_names).to include('knowledge_base_get_article')
        expect(tool_names).to include('knowledge_base_find_solutions')
      end
    end
  end

  describe TicketToolset do
    let(:toolset) { described_class.new }

    describe '#create_ticket' do
      it 'creates a new ticket with correct attributes' do
        ticket = toolset.create_ticket(
          customer_id: 'user-001',
          category: SupportCategory::Technical,
          priority: Priority::High,
          subject: 'API Error',
          description: 'Getting 500 errors'
        )

        expect(ticket).to be_a(Ticket)
        expect(ticket.id).to match(/TKT-\d+/)
        expect(ticket.category).to eq(SupportCategory::Technical)
        expect(ticket.priority).to eq(Priority::High)
        expect(ticket.status).to eq(TicketStatus::Open)
        expect(ticket.subject).to eq('API Error')
      end

      it 'generates unique ticket IDs' do
        ticket1 = toolset.create_ticket(
          customer_id: 'user-001',
          category: SupportCategory::Technical,
          priority: Priority::Low,
          subject: 'Test 1',
          description: 'Test'
        )

        ticket2 = toolset.create_ticket(
          customer_id: 'user-002',
          category: SupportCategory::Billing,
          priority: Priority::Medium,
          subject: 'Test 2',
          description: 'Test'
        )

        expect(ticket1.id).not_to eq(ticket2.id)
      end
    end

    describe '#update_ticket' do
      it 'updates ticket status' do
        ticket = toolset.create_ticket(
          customer_id: 'user-001',
          category: SupportCategory::Technical,
          priority: Priority::High,
          subject: 'Test',
          description: 'Test'
        )

        result = toolset.update_ticket(ticket_id: ticket.id, status: TicketStatus::Resolved)
        expect(result).to include('updated')
        expect(result).to include('resolved')

        updated_ticket = toolset.get_ticket(ticket_id: ticket.id)
        expect(updated_ticket.status).to eq(TicketStatus::Resolved)
      end

      it 'returns error message for non-existent ticket' do
        result = toolset.update_ticket(ticket_id: 'TKT-999', status: TicketStatus::Resolved)
        expect(result).to eq('Ticket not found')
      end
    end

    describe '#get_ticket' do
      it 'retrieves ticket by ID' do
        created_ticket = toolset.create_ticket(
          customer_id: 'user-001',
          category: SupportCategory::Technical,
          priority: Priority::High,
          subject: 'Test',
          description: 'Test'
        )

        retrieved_ticket = toolset.get_ticket(ticket_id: created_ticket.id)
        expect(retrieved_ticket).to eq(created_ticket)
      end

      it 'returns nil for non-existent ticket' do
        ticket = toolset.get_ticket(ticket_id: 'TKT-999')
        expect(ticket).to be_nil
      end
    end

    describe '#add_note' do
      it 'adds note to existing ticket' do
        ticket = toolset.create_ticket(
          customer_id: 'user-001',
          category: SupportCategory::Technical,
          priority: Priority::High,
          subject: 'Test',
          description: 'Test'
        )

        result = toolset.add_note(ticket_id: ticket.id, note: 'Customer called back')
        expect(result).to include('Note added')
        expect(result).to include(ticket.id)
      end

      it 'returns error for non-existent ticket' do
        result = toolset.add_note(ticket_id: 'TKT-999', note: 'Test note')
        expect(result).to eq('Ticket not found')
      end
    end

    describe '.to_tools' do
      it 'generates tools for all ticket operations' do
        tools = described_class.to_tools
        tool_names = tools.map(&:name)

        expect(tool_names).to include('ticket_create_ticket')
        expect(tool_names).to include('ticket_update_ticket')
        expect(tool_names).to include('ticket_get_ticket')
        expect(tool_names).to include('ticket_add_note')
      end
    end
  end

  describe UserInfoToolset do
    let(:toolset) { described_class.new }

    describe '#get_user' do
      it 'retrieves user information by ID' do
        user = toolset.get_user(user_id: 'user-001')
        expect(user).to be_a(UserInfo)
        expect(user.user_id).to eq('user-001')
        expect(user.name).to eq('Alice Johnson')
        expect(user.account_tier).to eq(AccountTier::Pro)
      end

      it 'returns nil for non-existent user' do
        user = toolset.get_user(user_id: 'user-999')
        expect(user).to be_nil
      end
    end

    describe '#check_billing_status' do
      it 'returns billing status for existing user' do
        result = toolset.check_billing_status(user_id: 'user-001')
        expect(result).to include('Alice Johnson')
        expect(result).to include('current')
        expect(result).to include('pro')
      end

      it 'returns error for non-existent user' do
        result = toolset.check_billing_status(user_id: 'user-999')
        expect(result).to eq('User not found')
      end
    end

    describe '#get_account_tier' do
      it 'returns tier information for existing user' do
        result = toolset.get_account_tier(user_id: 'user-001')
        expect(result).to include('Pro tier')
        expect(result).to include('10000 API calls/hour')
      end

      it 'returns correct tier info for different tiers' do
        basic_info = toolset.get_account_tier(user_id: 'user-002')
        expect(basic_info).to include('Basic tier')

        enterprise_info = toolset.get_account_tier(user_id: 'user-003')
        expect(enterprise_info).to include('Enterprise tier')
      end

      it 'returns error for non-existent user' do
        result = toolset.get_account_tier(user_id: 'user-999')
        expect(result).to eq('User not found')
      end
    end

    describe '.to_tools' do
      it 'generates tools for all user info operations' do
        tools = described_class.to_tools
        tool_names = tools.map(&:name)

        expect(tool_names).to include('user_info_get_user')
        expect(tool_names).to include('user_info_check_billing_status')
        expect(tool_names).to include('user_info_get_account_tier')
      end
    end
  end

  # ============================================================================
  # Data Structure Tests
  # ============================================================================

  describe 'Data Structures' do
    it 'creates valid Ticket struct' do
      ticket = Ticket.new(
        id: 'TKT-001',
        category: SupportCategory::Technical,
        priority: Priority::High,
        status: TicketStatus::Open,
        customer_id: 'user-001',
        subject: 'Test Subject',
        description: 'Test Description',
        created_at: Time.now.iso8601,
        updated_at: Time.now.iso8601
      )

      expect(ticket.id).to eq('TKT-001')
      expect(ticket.category).to eq(SupportCategory::Technical)
    end

    it 'creates valid UserInfo struct' do
      user = UserInfo.new(
        user_id: 'user-001',
        email: 'test@example.com',
        name: 'Test User',
        account_tier: AccountTier::Pro,
        account_status: 'active',
        billing_status: 'current',
        join_date: '2023-01-01'
      )

      expect(user.user_id).to eq('user-001')
      expect(user.account_tier).to eq(AccountTier::Pro)
    end

    it 'creates valid TriageResult struct' do
      triage = TriageResult.new(
        category: SupportCategory::Technical,
        priority: Priority::High,
        sentiment: SentimentLevel::Frustrated,
        suggested_agent: 'TechnicalSupportAgent',
        key_issues: ['API errors', 'timeout']
      )

      expect(triage.category).to eq(SupportCategory::Technical)
      expect(triage.key_issues).to include('API errors')
    end

    it 'creates valid SupportResponse struct' do
      response = SupportResponse.new(
        resolved: true,
        response_text: 'Issue resolved successfully',
        actions_taken: ['Checked logs', 'Reset connection'],
        ticket_id: 'TKT-001',
        follow_up_needed: false
      )

      expect(response.resolved).to be true
      expect(response.actions_taken).to be_an(Array)
    end
  end

  # ============================================================================
  # Agent Initialization Tests
  # ============================================================================

  describe 'Agent Initialization' do
    describe TriageAgent do
      it 'initializes successfully' do
        agent = described_class.new
        expect(agent).to be_a(DSPy::Module)
      end

      it 'uses ChainOfThought predictor' do
        agent = described_class.new
        expect(agent.instance_variable_get(:@predictor)).to be_a(DSPy::ChainOfThought)
      end
    end

    describe TechnicalSupportAgent do
      it 'initializes successfully' do
        agent = described_class.new
        expect(agent).to be_a(DSPy::Module)
      end

      it 'uses ReAct agent with tools' do
        agent = described_class.new
        react_agent = agent.instance_variable_get(:@agent)
        expect(react_agent).to be_a(DSPy::ReAct)
      end

      it 'has KB and ticket tools configured' do
        agent = described_class.new
        react_agent = agent.instance_variable_get(:@agent)
        tool_names = react_agent.tools.map(&:name)

        expect(tool_names).to include(match(/knowledge_base/))
        expect(tool_names).to include(match(/ticket/))
      end
    end

    describe BillingAgent do
      it 'initializes successfully' do
        agent = described_class.new
        expect(agent).to be_a(DSPy::Module)
      end

      it 'has user info, KB, and ticket tools configured' do
        agent = described_class.new
        react_agent = agent.instance_variable_get(:@agent)
        tool_names = react_agent.tools.map(&:name)

        expect(tool_names).to include(match(/user_info/))
        expect(tool_names).to include(match(/knowledge_base/))
        expect(tool_names).to include(match(/ticket/))
      end
    end

    describe AccountAgent do
      it 'initializes successfully' do
        agent = described_class.new
        expect(agent).to be_a(DSPy::Module)
      end

      it 'has user info, KB, and ticket tools configured' do
        agent = described_class.new
        react_agent = agent.instance_variable_get(:@agent)
        tool_names = react_agent.tools.map(&:name)

        expect(tool_names).to include(match(/user_info/))
        expect(tool_names).to include(match(/knowledge_base/))
        expect(tool_names).to include(match(/ticket/))
      end
    end

    describe CustomerSupportCoordinator do
      it 'initializes successfully' do
        coordinator = described_class.new
        expect(coordinator).to be_a(DSPy::Module)
      end

      it 'has all specialized agents configured' do
        coordinator = described_class.new
        expect(coordinator.instance_variable_get(:@triage_agent)).to be_a(TriageAgent)
        expect(coordinator.instance_variable_get(:@technical_agent)).to be_a(TechnicalSupportAgent)
        expect(coordinator.instance_variable_get(:@billing_agent)).to be_a(BillingAgent)
        expect(coordinator.instance_variable_get(:@account_agent)).to be_a(AccountAgent)
      end
    end
  end

  # ============================================================================
  # Type System Tests
  # ============================================================================

  describe 'Type System' do
    describe 'Enums' do
      it 'SupportCategory has correct values' do
        expect(SupportCategory::Technical.serialize).to eq('technical')
        expect(SupportCategory::Billing.serialize).to eq('billing')
        expect(SupportCategory::Account.serialize).to eq('account')
        expect(SupportCategory::General.serialize).to eq('general')
      end

      it 'Priority has correct values' do
        expect(Priority::Low.serialize).to eq('low')
        expect(Priority::Medium.serialize).to eq('medium')
        expect(Priority::High.serialize).to eq('high')
        expect(Priority::Urgent.serialize).to eq('urgent')
      end

      it 'TicketStatus has correct values' do
        expect(TicketStatus::Open.serialize).to eq('open')
        expect(TicketStatus::InProgress.serialize).to eq('in_progress')
        expect(TicketStatus::Resolved.serialize).to eq('resolved')
        expect(TicketStatus::Escalated.serialize).to eq('escalated')
      end

      it 'SentimentLevel has correct values' do
        expect(SentimentLevel::Positive.serialize).to eq('positive')
        expect(SentimentLevel::Neutral.serialize).to eq('neutral')
        expect(SentimentLevel::Negative.serialize).to eq('negative')
        expect(SentimentLevel::Frustrated.serialize).to eq('frustrated')
      end

      it 'AccountTier has correct values' do
        expect(AccountTier::Free.serialize).to eq('free')
        expect(AccountTier::Basic.serialize).to eq('basic')
        expect(AccountTier::Pro.serialize).to eq('pro')
        expect(AccountTier::Enterprise.serialize).to eq('enterprise')
      end
    end
  end

  # ============================================================================
  # Integration Tests (require LLM)
  # ============================================================================

  describe 'Integration Tests', vcr: { cassette_name: 'customer_support_multi_agent' } do
    before do
      # Skip if no API key is available
      skip 'No API key available' unless ENV['ANTHROPIC_API_KEY'] || ENV['OPENAI_API_KEY']

      DSPy.configure do |config|
        if ENV['ANTHROPIC_API_KEY']
          config.lm = DSPy::LM.new(
            'anthropic/claude-3-5-haiku-20241022',
            api_key: ENV['ANTHROPIC_API_KEY']
          )
        else
          config.lm = DSPy::LM.new(
            'openai/gpt-4o-mini',
            api_key: ENV['OPENAI_API_KEY']
          )
        end
      end
    end

    describe 'TriageAgent' do
      let(:agent) { TriageAgent.new }

      it 'correctly triages a technical issue' do
        result = agent.call(
          customer_query: 'My API is returning 500 errors',
          user_id: 'user-001'
        )

        expect(result.triage_result).to be_a(TriageResult)
        expect(result.triage_result.category).to eq(SupportCategory::Technical)
        expect(result.triage_result.priority).to be_a(Priority)
        expect(result.triage_result.suggested_agent).to be_a(String)
      end

      it 'correctly triages a billing issue' do
        result = agent.call(
          customer_query: 'I was charged twice this month',
          user_id: 'user-002'
        )

        expect(result.triage_result).to be_a(TriageResult)
        expect(result.triage_result.category).to eq(SupportCategory::Billing)
      end

      it 'detects customer sentiment' do
        result = agent.call(
          customer_query: 'This is ridiculous! Nothing is working!',
          user_id: 'user-001'
        )

        expect(result.triage_result.sentiment).to be_a(SentimentLevel)
      end
    end

    describe 'CustomerSupportCoordinator' do
      let(:coordinator) { CustomerSupportCoordinator.new }

      it 'handles technical support request end-to-end' do
        result = coordinator.handle_request(
          customer_query: 'I am getting rate limit errors on my API calls',
          user_id: 'user-001'
        )

        expect(result.support_response).to be_a(SupportResponse)
        expect(result.support_response.response_text).to be_a(String)
        expect(result.support_response.actions_taken).to be_an(Array)
        expect(result.support_response.actions_taken).not_to be_empty
      end
    end
  end
end
