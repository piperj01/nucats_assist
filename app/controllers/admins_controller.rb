class AdminsController < ApplicationController

  before_filter  :set_project

  require 'csv_generator'
  
  #all admin methods have a :sponsor_id set

  def index
    @sponsor = @project.program
    if has_read_all?(@sponsor) then
      @submissions = Submission.all(:include=>[:key_personnel, :applicant, :submitter, :reviewers], :conditions=>["project_id = :project_id",{:project_id => @project.id}])
      
      @applicants = @submissions.collect{|s| s.applicant }.compact.uniq.sort{ |a,b| a.last_name.downcase+' '+a.first_name.downcase <=> b.last_name.downcase+' '+b.first_name.downcase }
      @key_personnel = (@submissions.collect{|s| s.key_personnel.collect{ |k| k } }.flatten).compact.uniq.sort{ |a,b| a.last_name.downcase+' '+a.first_name.downcase <=> b.last_name.downcase+' '+b.first_name.downcase }
      @core_managers = @submissions.collect{|t| t.core_manager}.flatten.compact.uniq.sort{ |a,b| a.last_name.downcase+' '+a.first_name.downcase <=> b.last_name.downcase+' '+b.first_name.downcase }
      @submitters = @submissions.collect{|s| s.submitter }.compact.uniq.sort{ |a,b| a.last_name.downcase+' '+a.first_name.downcase <=> b.last_name.downcase+' '+b.first_name.downcase }
      @approvers = @submissions.collect{|e| e.effort_approver }.compact.uniq.sort{ |a,b| a.last_name.downcase+' '+a.first_name.downcase <=> b.last_name.downcase+' '+b.first_name.downcase }
      @business_admins = @submissions.collect{|e| e.department_administrator }.compact.uniq.sort{ |a,b| a.last_name.downcase+' '+a.first_name.downcase <=> b.last_name.downcase+' '+b.first_name.downcase }
      @reviewers = @submissions.collect{|e| e.reviewers.collect{|r| r} }.flatten.compact.uniq.sort{ |a,b| a.last_name.downcase+' '+a.first_name.downcase <=> b.last_name.downcase+' '+b.first_name.downcase }
#      @users = (@applicants+@key_personnel.collect{|e| e.user}.flatten+@core_managers+@submitters+@approvers+@business_admins+@reviewers).compact.uniq
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => @users }
      end
    else
      redirect_to projects_path
    end
  end

  def view_applicants
    #applicants for all competitions
    start_date = Date.today.beginning_of_year()
    start_date -= 365 if Date.today - start_date < 90
    @submissions = Submission.all(:conditions=>["submissions.created_at > :start", {:start=>start_date}], :include=>[:applicant])
    
    @activity="all applicants"
    if has_read_all?(@sponsor) then
      respond_to do |format|
        format.html { render :view_applicants }
        format.xml  { render :xml => @applicants }
        format.pdf do
          @pdf = 1
          render :pdf => "Applicant listing for #{Date.today.year}", 
              :template => 'admins/view_applicants.html',
              :stylesheets => ["pdf"], 
              :layout => "pdf"
        end
        format.xls do
          @pdf = 1
           send_data(render(:template => 'admins/view_applicants.html', :layout => "excel"),
          :filename => "Applicant listing for #{Date.today.year}.xls",
          :type => 'application/vnd.ms-excel',
          :disposition => 'attachment') 
        end
      end
    else
      redirect_to projects_path
    end
  end


  def view_activities
    @sponsor = @project.program
    @logs = @sponsor.logs
    @activity="all logged"
    render_view_activities
  end

  def view_logins
    @sponsor = @project.program
    @logs = @project.logs.logins
    @activity="login"
    render_view_activities
  end
  
  def view_submissions
    @sponsor = @project.program
    @logs = @project.logs.submissions
    @activity="submission"
    render_view_activities
  end
  
  def view_reviews
     @sponsor = @project.program
    @logs = @project.logs.reviews
    @activity="review"
    render_view_activities
  end
  
  def act_as_user
    @sponsor = @project.program
    if is_super_admin? then
      if defined? params[:username].blank?
        @users = User.all
      else
        @current_user_session = User.find_by_username(params[:username]) 
        session[:username]=@current_user_session.username
        session[:name]=@current_user_session.name
        # manual Aker call
        user = Aker::User.new(params[:username], :NUCATSassist)
        session[:aker_user]=user
        check_session
        act_as_admin
         
        redirect_to projects_path
      end
    else
      redirect_to projects_path
    end
  end      

  def submissions
    @sponsor = @project.program
    if has_read_all?(@sponsor) then
      @submissions = @project.submissions
    else
      redirect_to projects_path
    end
  end

  def reviews
    @sponsor = @project.program
    if has_read_all?(@sponsor) then
      @submissions = @project.submissions
    else
      redirect_to projects_path
    end
  end

  def reviewers
    @sponsor = @project.program
    if has_read_all?(@sponsor) then
      prep_reviewer_data
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => @reviewers }
      end
    else
      redirect_to projects_path
    end
  end
  
  def add_reviewers
    @sponsor = @project.program
    if is_admin?(@sponsor) then
      flash[:notice] = ''
      reviewers_to_add = params[:admin][:reviewer_list].split(/\s*,\s*|\s+/)
      reviewers_to_add.each do | netid |
        netid=netid.strip
        if make_user(netid)
          the_user = User.find_by_username(netid)
          if the_user.nil? or the_user.id.nil?
            flash[:notice] += "make_user returned true, however could not find netid #{netid}; "
          else
            reviewer = Reviewer.find(:first, :conditions=>['(program_id = :program_id and user_id = :user_id)', {:program_id => @sponsor.id, :user_id => the_user.id} ])
            if reviewer.nil? or reviewer.id.nil?
              flash[:notice] += "Added #{netid} (#{the_user.name}) as reviewer; "
              reviewer = Reviewer.new(:program_id=>@sponsor.id, :user_id=>the_user.id)
              before_create(reviewer)
              reviewer.save
            else
              flash[:notice] += "Reviewer #{netid} (#{the_user.name}) was already assigned; "
            end
          end
        else
          flash[:notice] += "Could not find netid #{netid}; "
        end
      end
      prep_reviewer_data
      render :action => "reviewers"
    else
      redirect_to projects_path
    end
  end
  
  def remove_reviewer
    @sponsor = @project.program
    if is_admin?(@sponsor) then
      flash[:notice] = ''
      the_reviewer = Reviewer.find_by_id(params[:id])
      if the_reviewer.nil? or the_reviewer.id.nil?
        flash[:notice] += "Could not find reviewer #{params[:id]}! "
      else
        the_user = the_reviewer.user
        user_reviews = the_user.submission_reviews.this_project(@project.id)
        flash[:notice] += "Removed reviewer #{the_user.name}"
        if user_reviews.length > 0 then
          flash[:notice] += "; NOTE: DELETED #{user_reviews.length} reviews"
          user_reviews.each do |sr|
            sr.destroy
          end
        end
        the_reviewer.destroy
      end
      prep_reviewer_data
      render :action => "reviewers"
    else
      redirect_to projects_path
    end
  end
  
  # personnel_data, applicant_data, submission_data, key_personnel_data all have csv feeds to the amCharts graph

  def personnel_data
    users = User.all.compact.uniq
    data = generate_csv(users)
    render :template => "shared/csv_data", :locals => {:data => data}, :layout => false
  end
  
  def application_data
    applications = Submission.all
    data = generate_csv(applications)
    render :template => "shared/csv_data", :locals => {:data => data}, :layout => false
  end

  def applicant_data
    applicants = Submission.all.collect{|s| s.applicant }.compact.uniq
    data = generate_csv(applicants)
    render :template => "shared/csv_data", :locals => {:data => data}, :layout => false
  end
  
  def submission_data
    submissions = Submission.all.compact.uniq
    data = generate_csv(submissions)
    render :template => "shared/csv_data", :locals => {:data => data}, :layout => false
  end
  
  def key_personnel_data
    key_personnel = Submission.all.collect{|s| s.key_personnel.collect{ |k| k } }.flatten.compact.uniq
    data = generate_csv(key_personnel)
    render :template => "shared/csv_data", :locals => {:data => data}, :layout => false
  end
  
  def reviewer_data
    reviewer = SubmissionReview.all.compact.uniq
    data = generate_csv(reviewer)
    render :template => "shared/csv_data", :locals => {:data => data}, :layout => false
  end

  def review_data
    reviews = SubmissionReview.find(:all, :conditions=>['overall_score > 0'])
    data = generate_csv(reviews, true)
    render :template => "shared/csv_data", :locals => {:data => data}, :layout => false
  end
  
  def login_data
    logs = Log.logins
    data = generate_csv(logs, true)
    render :template => "shared/csv_data", :locals => {:data => data}, :layout => false
  end

  
  
  def show
  end
  
  def assign_submission
    @sponsor = @project.program
    if is_admin?(@sponsor) then
      @reviewer = User.find(params[:id])
      @submission = Submission.find(params[:submission_id])
      @review = @submission.submission_reviews.find_by_reviewer_id(params[:id])
      @submission.submission_reviews << SubmissionReview.new(:submission_id=>params[:submission], :reviewer_id => @reviewer.id) if @review.blank?
    end
    update_review_assignment 
  end

  def unassign_submission
    @sponsor = @project.program
    if is_admin?(@sponsor) then
      @review = SubmissionReview.find_by_id(params[:submission_review_id])
      unless @review.blank?
        @reviewer = @review.user
        @submission = @review.submission
       #SubmissionReview.delete(params[:submission_review_id])
        @submission.submission_reviews.destroy(@review) 
        update_review_assignment 
      end
    end
  end

  private

  def render_view_activities
    if has_read_all?(@sponsor) then
       respond_to do |format|
        format.html { render :view_activities }
        format.xml  { render :xml => @logs }
      end
    else
      redirect_to projects_path
    end
  end

  def update_review_assignment()
    @unfilled_submissions = Submission.unfilled_submissions(@project.max_assigned_proposals_per_reviewer).find_all_by_project_id(@project.id)
    render :update do |page|
      page.replace_html "assigned_submissions_#{@reviewer.id}", :partial => 'assigned_submissions', :locals=> {:reviewer=>@reviewer, :project=>@project}
      page.replace_html 'unassigned_submissions', :partial => 'unassigned_submissions', :locals=>{:unfilled_submissions=>@unfilled_submissions}
    end
  end

  def prep_reviewer_data
    @reviewers = @sponsor.reviewers
#    @submissions = Submission.find_all_by_project_id(session[:project_id])
    @unfilled_submissions = @project.submissions.unfilled_submissions(@project.max_assigned_proposals_per_reviewer)
  end
  
  def set_project
    if defined?(params)
      unless  params[:project_id].blank?
        @project = Project.find(params[:project_id])
        set_current_project(@project)
      end
    end
  end

end
