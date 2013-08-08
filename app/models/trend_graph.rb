class TrendGraph

GRAPH_CONFIG = YAML.load_file(File.dirname(__FILE__) + '/../../config/config.yml')

  def initialize(project_id, each_by)
    @project_id = project_id
    @each_by = each_by
    #case each_by
    #when 'hour'
    #  @item_count = 24
    #when 'wday'
    #  @item_count = 7
    #when 'day'
    #  @item_count = 31 + 1 # (useless)0-day to 31-day
    #end
  end

  def count(target_month)
    case @each_by
      when 'hour'
        @item_count = 24
      when 'wday'
        @item_count = 7
      when 'day'
        # (useless)0-day to 31-day
        @item_count = Time.days_in_month(target_month.strftime('%m').to_i, target_month.strftime('%Y').to_i) + 1
    end

    created_issues = Issue.find(:all,
                                :select => :created_on,
                                :order => "created_on ASC",
                                :conditions => ["project_id = ? and " +
                                                "created_on >= ? and " +
                                                "created_on < ? ",
                                                @project_id,
                                                target_month,
                                                target_month + 1.month])
    count_each_time = Array.new(@item_count,0)
    time_zone = GRAPH_CONFIG["local_time_zone"]
    created_issues.each do |issue|
      #count_each_time[issue.created_on.send(@each_by)] += 1
      count_each_time[issue.created_on.in_time_zone(time_zone).send(@each_by)] += 1
    end
    count_each_time.shift if @each_by == 'day' # 0 day is not necessary
    return count_each_time
  end

end
