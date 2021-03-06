require 'test_helper'

class ApplicantsControllerTest < ActionController::TestCase

  
  test "should get index" do
    get(:index, {'project_id' => projects(:three).to_param})
    assert_response :success
    assert_not_nil assigns(:project)
    assert assigns(:applicants) == []
  end

  test "should get index for project1" do
    get(:index, {'project_id' => "1"})
    assert_response :success
    assert_not_nil assigns(:project)
    assert assigns(:applicants) == []
  end

  test "should get new" do
    get :new
    assert_response :redirect
    assert_redirected_to applicants_path
  end

  test "should get new 2" do
    get :new, {:username=>'spuds', 'project_id' => "1"}
    assert_template 'applicants/new'
    assert_response :success
  end

  test "should create applicant" do
    assert_difference('User.count') do
      post :create, {'project_id' => "1", :applicant => {:username=>"spuds", :first_name=>"idaho", :last_name=>"idaho", :email=>"idaho@spuds.com" }}
    end
    assert_not_nil assigns(:project)
    assert_response :redirect
    #assert_redirected_to applicant_path(assigns(:applicant))
  end

  test "should show applicant" do
    get :show, :id => users(:three).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => users(:three).to_param
    assert_response :success
  end

  test "should update applicant" do
    put :update, :id => "3", :project_id => projects(:three).to_param, :applicant => { }
    assert_not_nil assigns(:applicant )
    assert_redirected_to new_project_applicant_submission_path(projects(:three).to_param, 3)
  end

  test "should destroy applicant" do
    assert_difference('User.count', 0) do
      delete :destroy, :id => "3", :project_id => "1"
    end
    assert_not_nil assigns(:applicant )
  end
  
  test "should destroy applicant2" do
    assert_difference('User.count', 0) do
      delete :destroy, :id => "3"
    end
    assert_not_nil assigns(:applicant )
    assert_redirected_to applicants_path
  end
end
