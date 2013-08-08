# encoding: utf-8
class GraphMakerController < ApplicationController
  unloadable

  before_filter :find_project
  before_filter :authorize,
                :only => [:select_view,
                          :show_long,
                          :show_trend,
                          :show_customize,
                          :show_completion]

  before_filter :get_target_month,
                :only => [:show_trend,
                          :get_trend_graph,
                          :show_completion,
                          :get_completion_graph,
                          :export_trend_csv]

  before_filter :get_months_up_to_now,
                :only => [:show_trend,
                          :show_completion]

  menu_item :long_graph, :only => :show_long
  menu_item :trend_graph, :only => :show_trend
  menu_item :completion_graph, :only => :show_completion
  menu_item :customize_graph, :only => :show_customize

  helper :queries
  include QueriesHelper
  helper :sort
  include SortHelper

  require 'csv'
  require 'kconv'

  def show_customize
    @queries = Query.find_all_by_project_id(@project.id)
    @group_labels = @queries.map do |query|
      if query.group_by =~ /cf_(\d+)/
        CustomField.find($1).name
      else
        I18n.t('field_' + query.group_by)
      end
    end
  end

  def show_long

  end

  def show_trend
  end

  def show_completion

    @first_interval = params[:first_interval]
    @first_interval ||= CompletionGraph::DEFAULT_FIRST_INTERVAL

    advanced_issue = AdvancedIssue.new(CompletionGraph.new(@project.id))

    intervals = CompletionGraph.intervals(@first_interval)
    @counts = advanced_issue.count(intervals, @target_month)

    @labels = Array.new
    @table_labels = Array.new
    intervals.each do |interval|
      @labels.push(AdvancedDate.get_formatted_time(interval, :less_than, true))
      @table_labels.push(AdvancedDate.get_formatted_time(interval, :less_than))
    end
    @labels.push(AdvancedDate.get_formatted_time(intervals.last, :more_than, true))
    @table_labels.push(AdvancedDate.get_formatted_time(intervals.last, :more_than))

    @all_labels = Hash.new
    CompletionGraph::INTERVALS.keys.sort.each do |key|
      @all_labels[key] = Array.new
      CompletionGraph::INTERVALS[key].each do |interval|
        display_time = AdvancedDate.get_formatted_time(interval, :less_than)
        @all_labels[key].push display_time
      end
      display_time = AdvancedDate.get_formatted_time(CompletionGraph::INTERVALS[key].last, :more_than)
      @all_labels[key].push display_time
    end

  end

  def get_completion_graph
    counts = params[:counts].map { |count_str| count_str.to_i }
    labels = params[:labels]

    graph = CustomizedGraph.new("完了時間毎のチケット件数", 600, Gruff::Bar)
    graph.push_data("チケット数", counts)

    graph.set_labels_from_array(labels)

    send_data(graph.blob,
              :type => 'image/png',
              :disposition => 'inline')

  end


  def get_trend_graph
    graph = CustomizedGraph.new(I18n.t("graph_title.trend_#{params[:each_by]}"),
                                600,
                                "Gruff::#{params[:graph_variation]}".constantize)

    trend_graph = AdvancedIssue.new(TrendGraph.new(@project.id,
                                                   params[:each_by]))
    count_each_time = trend_graph.count(@target_month)

    #graph.push_data("直近1ヶ月分 ",
    graph.push_data(@target_month.strftime('%Y年 %m月'),
                    count_each_time)

    count_each_time.size.times do |num|
      case params[:each_by]
        when 'day'
          label = (num + 1).to_s
        when 'wday'
          label = I18n.t("graph_items.wday_#{num}")
        when 'hour'
          label = num.to_s
      end
      graph.push_label(label)
    end

    send_data(graph.blob,
              :type => 'image/png',
              :disposition => 'inline')

  end

  def get_long_graph
    long_graph = AdvancedIssue.new(LongGraph.new(@project.id,
                                                 @project.trackers,
                                                 params[:year]))
    graph = CustomizedGraph.new("#{params[:year]}年度のチケット件数",
                                600,
                                Gruff::Line)

    count_each_tracker = long_graph.count

    @project.trackers.each do |tracker|
      graph.push_data(tracker.name,
                      count_each_tracker[tracker])
    end

    april = DateTime.new(DateTime.now.year, 4)
    12.times do |num|
      graph.push_label((april + num.month).month.to_s + "月")
    end

    send_data(graph.blob,
              :type => 'image/png',
              :disposition => 'inline')

  end

  def get_customize_graph
    retrieve_query
    @issue_count_by_group = @query.issue_count_by_group

    graph = CustomizedGraph.new(@query.name,
                                600,
                                Gruff::Pie)

    @issue_count_by_group.each do |group, count|
      group_name = group.to_s.size == 0 ? 'None' : group.to_s
      graph.push_data(group_name, count)
    end

    send_data(graph.blob,
              :type => 'image/png',
              :disposition => 'inline')

  end

  def export_trend_csv
    trend_graph = AdvancedIssue.new(TrendGraph.new(@project.id, params[:each_by]))
    count_each_time = trend_graph.count(@target_month)

    data = CSV.generate do |csv|
      csv << [params[:each_by], "count"]

      count_each_time.size.times do |num|
        case params[:each_by]
          when 'day'
            label = (num + 1).to_s
          when 'wday'
            label = I18n.t("graph_items.wday_#{num}")
          when 'hour'
            label = num.to_s
        end
        csv << [label, count_each_time[num]]
      end
    end

    data = data.tosjis if data
    send_data(data, type: 'text/csv;charset=shift_jis',
              filename: "trend_graph_" + params[:each_by] + "_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv")
  end

  def export_customize_csv
    retrieve_query
    @issue_count_by_group = @query.issue_count_by_group

    data = CSV.generate do |csv|
      csv << ["group", "count"]
      @issue_count_by_group.each do |group, count|
        group_name = group.to_s.size == 0 ? 'None' : group.to_s
        csv << [group_name, count]
      end
    end

    data = data.tosjis if data
    send_data(data, type: 'text/csv;charset=shift_jis',
              filename: "customize_graph_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv")
  end

  def export_completion_csv
    counts = params[:counts].map { |count_str| count_str.to_i }
    labels = params[:labels]

    data = CSV.generate do |csv|
      csv << ["completion", "count"]
      labels.size.times do |num|
        csv << [labels[num], counts[num]]
      end
    end

    data = data.tosjis if data
    send_data(data, type: 'text/csv;charset=shift_jis',
              filename: "completion_graph_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv")
  end

  def export_long_csv
    long_graph = AdvancedIssue.new(LongGraph.new(@project.id,
                                                 @project.trackers,
                                                 params[:year]))
    count_each_tracker = long_graph.count

    csv_header = ["month"]
    @project.trackers.each do |tracker|
      csv_header << tracker.name
    end

    april = DateTime.new(DateTime.now.year, 4)
    data = CSV.generate do |csv|
      csv << csv_header
      12.times do |num|
        csv_data = [(april + num.month).month.to_s + "月"]
        @project.trackers.each do |tracker|
          csv_data << count_each_tracker[tracker][num]
        end
        csv << csv_data
      end
    end

    data = data.tosjis if data
    send_data(data, type: 'text/csv;charset=shift_jis',
              filename: "long_graph_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv")
  end

  private
  def find_project
    @project = Project.find_by_identifier(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def get_target_month
    if params[:target_month] && params[:target_month] =~ /\d+(\/\d+){2}/
      @target_month = DateTime.parse(params[:target_month])
    else
      #@target_month = DateTime.now - 1.month
      @target_month = DateTime.new(DateTime.now.year, DateTime.now.month, 1)
    end
  end

  def get_months_up_to_now
    @months = AdvancedDate.months_up_to_now(@project.created_on)
  end
end
