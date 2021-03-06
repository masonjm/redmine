class BacklogsController < ApplicationController
  unloadable
  
  helper :issues
  
  menu_item :product_backlog, :only => [:product]
  menu_item :sprint_backlog, :only => [:sprint]
  
  before_filter :find_project, :authorize

  def sprint
    @current_sprint = @project.current_version
    render_error("There is no current Sprint for this Project") and return unless @current_sprint
    
    @task_tracker = @project.trackers.detect {|tracker| 'task' == tracker.name.downcase }
    
    @backlog_title = "Sprint Backlog Tickets"    
    
    backlog_url_opts = {:controller => 'issues', :project_id => @project, :set_filter => 1, 
      :group => 'story', :per_page => 100,
      :fields => [:status_id, :fixed_version_id], 
      :operators => {:status_id => '*', :fixed_version_id => '='}, 
      :values => {:status_id => [1], :fixed_version_id => [@current_sprint.id]},
      :column_names => [:tracker, :category, :priority, :subject, :assigned_to, :status, :estimated_hours, :done_ratio].compact}
    @backlog_url = url_for(backlog_url_opts)
    @only_open_backlog_url = url_for(backlog_url_opts.merge(:operators => {:status_id => 'o', :fixed_version_id => '='}))
    
    @velocity_chart = VelocityChart.new(@project)
  end
  
  def product
    @story_tracker = @project.trackers.detect {|tracker| 'story' == tracker.name.downcase }
    
    sort_key = "enumerations.position desc, rank "
    
    @backlog_title = "Product Backlog Tickets"
    @backlog_url = url_for({:controller => 'issues', :set_filter => 1, :project_id => @project,
      :fields => [:status_id, :tracker_id, :fixed_version_id], 
      :operators => {:status_id => 'o', :tracker_id => '!', :fixed_version_id => '!*'}, 
      :values => {:status_id => 'o', :fixed_version_id => [1], :tracker_id => [3]},
      :column_names => [:tracker, :priority, :subject, :updated_on, story_points_name].compact, 
      :sort_key => sort_key, :sort_order => 'asc', :group => 'priority'})
  end
  
  def prioritize
    dragged_id = params[:dragged_id] =~ /issue-(\d+)/ && $1
    issue = Issue.find(dragged_id)
    
    new_position = params[:issue_list].index(dragged_id)

    if new_position == params[:issue_list].size - 1 # end of list
      issue.insert_at(Issue.find(params[:issue_list][-2]).rank)
    else # beginning (0) or middle (non-0)
      issue.insert_at(Issue.find(params[:issue_list][new_position+1]).rank)
    end
    
    render :nothing => true
  end

private

  def story_points_name
    story_points_field = IssueCustomField.find_by_name("Story Points")
    story_points_field && "cf_#{story_points_field.id}" # janky, but loading QueryCustomFieldColumn is a pain.
  end

  def find_project
    @project = if params[:id]
      Project.find(params[:id])
    else
      project = Project.first
      project.parent || project
    end
  end
end