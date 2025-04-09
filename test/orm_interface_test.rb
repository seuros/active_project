# frozen_string_literal: true

require "test_helper"

class OrmInterfaceTest < ActiveSupport::TestCase
  def setup
    # Clear config and memoized adapters
    ActiveProject.instance_variable_set(:@configuration, nil)
    ActiveProject.instance_variable_set(:@adapters, nil)

    # Configure dummy adapters
    ActiveProject.configure do |config|
      config.add_adapter :trello, :primary,  api_key: "key", api_token: "token"
      config.add_adapter :jira, :primary,  site_url: "url", username: "user", api_token: "token"
      config.add_adapter :basecamp, :primary,  account_id: "id", access_token: "token"
    end

    @jira_adapter = ActiveProject.adapter(:jira)
    @trello_adapter = ActiveProject.adapter(:trello)
    @basecamp_adapter = ActiveProject.adapter(:basecamp)

    # Mock adapter methods to return dummy Resource objects
    # Note: We mock the *adapter's* methods, which the factory/proxy will call.
    @dummy_jira_project = ActiveProject::Resources::Project.new(@jira_adapter, id: "10000", key: "JRA", name: "Jira Project", adapter_source: :jira)
    @dummy_jira_issue = ActiveProject::Resources::Issue.new(@jira_adapter, id: "10001", key: "JRA-1", title: "Jira Issue", project_id: "10000", status: :open, adapter_source: :jira)
    @dummy_trello_board = ActiveProject::Resources::Project.new(@trello_adapter, id: "board1", name: "Trello Board", adapter_source: :trello)
    @dummy_trello_card = ActiveProject::Resources::Issue.new(@trello_adapter, id: "card1", title: "Trello Card", project_id: "board1", status: :open, adapter_source: :trello)
    @dummy_bc_project = ActiveProject::Resources::Project.new(@basecamp_adapter, id: 1, name: "BC Project", adapter_source: :basecamp)
    @dummy_bc_todo = ActiveProject::Resources::Issue.new(@basecamp_adapter, id: 2, title: "BC Todo", project_id: 1, status: :open, adapter_source: :basecamp)
    @dummy_bc_comment = ActiveProject::Resources::Comment.new(@basecamp_adapter, id: 3, body: "BC Comment", issue_id: 2, adapter_source: :basecamp)

    # Stub adapter methods that will be called by factory/proxy
    @jira_adapter.stubs(:list_projects).with({}).returns([ @dummy_jira_project ]) # list_projects takes options hash
    @jira_adapter.stubs(:find_project).with("JRA").returns(@dummy_jira_project)
    @jira_adapter.stubs(:list_issues).with("10000", {}).returns([ @dummy_jira_issue ])
    @jira_adapter.stubs(:find_issue).with("JRA-1").returns(@dummy_jira_issue)
    # Stub create_issue on the adapter, as factory#create calls adapter#create_issue
    # Factory#create now passes attributes hash directly
    @jira_adapter.stubs(:create_issue).with(has_entries(summary: "Create Test")).returns(@dummy_jira_issue)

    @trello_adapter.stubs(:list_projects).with({}).returns([ @dummy_trello_board ])
    @trello_adapter.stubs(:find_project).with("board1").returns(@dummy_trello_board)
    @trello_adapter.stubs(:list_issues).with("board1", {}).returns([ @dummy_trello_card ])
    @trello_adapter.stubs(:find_issue).with("card1").returns(@dummy_trello_card)

    @basecamp_adapter.stubs(:list_projects).with({}).returns([ @dummy_bc_project ])
    @basecamp_adapter.stubs(:find_project).with(1).returns(@dummy_bc_project)
    @basecamp_adapter.stubs(:list_issues).with(1, {}).returns([ @dummy_bc_todo ])
    @basecamp_adapter.stubs(:find_issue).with(2, { project_id: 1 }).returns(@dummy_bc_todo)
    # Basecamp add_comment is called by association proxy, stub it if testing comments.all
    # @basecamp_adapter.stubs(:list_comments).with(2, { project_id: 1 }).returns([@dummy_bc_comment]) # Assuming list_comments exists
  end

  # --- Step 6a: Factory Interface Tests ---

  test "adapter responds to factory methods" do
    assert_respond_to @jira_adapter, :projects
    assert_respond_to @jira_adapter, :issues
    assert_respond_to @trello_adapter, :projects
    assert_respond_to @trello_adapter, :issues
    assert_respond_to @basecamp_adapter, :projects
    assert_respond_to @basecamp_adapter, :issues
  end

  test "factory #all calls adapter list method" do
    # Use the factory returned by the adapter method
    projects = @jira_adapter.projects.all
    assert_equal 1, projects.count
    assert_instance_of ActiveProject::Resources::Project, projects.first
    assert_equal @dummy_jira_project, projects.first

    # Pass context arg directly to #all if needed by the underlying list method
    issues = @trello_adapter.issues.all("board1") # Trello list_issues takes board_id
    assert_equal 1, issues.count
    assert_instance_of ActiveProject::Resources::Issue, issues.first
    assert_equal @dummy_trello_card, issues.first
  end

  test "factory #find calls adapter find method" do
    project = @jira_adapter.projects.find("JRA")
    assert_instance_of ActiveProject::Resources::Project, project
    assert_equal @dummy_jira_project, project

    # Pass context hash as second argument to factory#find
    issue = @basecamp_adapter.issues.find(2, { project_id: 1 })
    assert_instance_of ActiveProject::Resources::Issue, issue
    assert_equal @dummy_bc_todo, issue
  end

  test "factory #first calls adapter list method and returns first" do
    project = @trello_adapter.projects.first
    assert_instance_of ActiveProject::Resources::Project, project
    assert_equal @dummy_trello_board, project
  end

  # --- Step 6b: Association Access Tests ---

  test "project.issues association returns proxy" do
    assert_instance_of ActiveProject::AssociationProxy, @dummy_jira_project.issues
  end

  test "project.issues.all calls adapter list_issues with project id" do
    issues = @dummy_jira_project.issues.all # Proxy's #all should pass owner ID
    assert_equal 1, issues.count
    assert_equal @dummy_jira_issue, issues.first
  end

  test "issue.comments association returns proxy" do
     assert_respond_to @dummy_bc_todo, :comments
     assert_instance_of ActiveProject::AssociationProxy, @dummy_bc_todo.comments
  end

  # test "issue.comments.all calls adapter list_comments" do
  #   # Requires list_comments implementation and stubbing
  # end

  # --- Step 6c: #where Clause Tests ---

  test "factory #where performs client-side filtering" do
    # Add another dummy issue for filtering
    @dummy_jira_issue_closed = ActiveProject::Resources::Issue.new(@jira_adapter, id: "10002", key: "JRA-2", title: "Closed Jira Issue", project_id: "10000", status: :closed, adapter_source: :jira)
    @jira_adapter.stubs(:list_issues).with("10000", {}).returns([ @dummy_jira_issue, @dummy_jira_issue_closed ])

    # Use the factory for where, passing list args after conditions
    open_issues = @jira_adapter.issues.where({ status: :open }, "10000")
    closed_issues = @jira_adapter.issues.where({ status: :closed }, "10000")

    assert_equal 1, open_issues.count
    assert_equal @dummy_jira_issue, open_issues.first
    assert_equal 1, closed_issues.count
    assert_equal @dummy_jira_issue_closed, closed_issues.first
  end

  # --- Step 6d: #build, #create, #save, #update Tests ---

  test "factory #build creates a new resource instance" do
    new_issue = @jira_adapter.issues.build(title: "New Build Test", project: { id: "10000" })
    assert_instance_of ActiveProject::Resources::Issue, new_issue
    assert_equal "New Build Test", new_issue.title
    assert_equal :jira, new_issue.adapter_source
    assert_same @jira_adapter, new_issue.adapter # Check adapter is passed
  end

  test "resource #save raises NotImplementedError" do
    issue = @jira_adapter.issues.build(title: "Save Test")
    # Check for the specific error message from the placeholder
    exception = assert_raises(ActiveProject::NotImplementedError) { issue.save }
    assert_match(/#save not yet implemented/, exception.message)
  end

   test "resource #update raises NotImplementedError" do
    # Check for the specific error message from the placeholder
    exception = assert_raises(ActiveProject::NotImplementedError) do
      @dummy_jira_issue.update(title: "Update Test")
    end
    assert_match(/#update not yet implemented/, exception.message)
  end

  test "factory #create calls adapter create method" do
     # Use the factory create method
     # Factory#create now calls adapter#create_issue directly
     created_issue = @jira_adapter.issues.create(
       project: { key: "JRA" },
       summary: "Create Test", # Use summary as per adapter create_issue
       issue_type: { name: "Task" }
     )
     # Assert that the stubbed adapter method returned the expected object.
     assert_instance_of ActiveProject::Resources::Issue, created_issue
     assert_equal @dummy_jira_issue, created_issue
  end
end
