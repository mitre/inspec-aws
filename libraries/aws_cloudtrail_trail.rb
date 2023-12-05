require "aws_backend"

class AwsCloudTrailTrail < AwsResourceBase
  name "aws_cloudtrail_trail"
  desc "Verifies settings for an individual AWS CloudTrail Trail."
  example <<-EXAMPLE
    describe aws_cloudtrail_trail('TRIAL_NAME') do
      it { should exist }
    end
  EXAMPLE

  attr_reader :cloud_watch_logs_log_group_arn, :cloud_watch_logs_role_arn, :home_region, :trail_name,
              :kms_key_id, :s3_bucket_name, :s3_key_prefix, :trail_arn, :is_multi_region_trail,
              :log_file_validation_enabled, :is_organization_trail, :event_selectors

  alias multi_region_trail? is_multi_region_trail
  alias log_file_validation_enabled? log_file_validation_enabled
  alias has_log_file_validation_enabled? log_file_validation_enabled
  alias organization_trail? is_organization_trail

  def initialize(opts = {})
    opts = { trail_name: opts } if opts.is_a?(String)
    super(opts)
    validate_parameters(required: [:trail_name])

    @trail_name = opts[:trail_name]
    @event_selectors = []
    catch_aws_errors do
      resp = @aws.cloudtrail_client.describe_trails({ trail_name_list: [@trail_name] })
      @trail = resp.trail_list[0].to_h
      @trail_arn = @trail[:trail_arn]
      @kms_key_id = @trail[:kms_key_id]
      @home_region = @trail[:home_region]
      @s3_bucket_name = @trail[:s3_bucket_name]
      @s3_key_prefix = @trail[:s3_key_prefix]
      @is_organization_trail = @trail[:is_organization_trail]
      @is_multi_region_trail = @trail[:is_multi_region_trail]
      @cloud_watch_logs_role_arn = @trail[:cloud_watch_logs_role_arn]
      @log_file_validation_enabled = @trail[:log_file_validation_enabled]
      @cloud_watch_logs_log_group_arn = @trail[:cloud_watch_logs_log_group_arn]
      @event_selectors = @aws.cloudtrail_client.get_event_selectors(trail_name: @trail_name)
    end
  end

  def resource_id
    @trail_arn
  end

  def delivered_logs_days_ago
    return nil unless exists?
    catch_aws_errors do
      begin
        trail_status = @aws.cloudtrail_client.get_trail_status({ name: @trail_name }).to_h
        ((Time.now - trail_status[:latest_cloud_watch_logs_delivery_time]) / (24 * 60 * 60)).to_i unless trail_status[:latest_cloud_watch_logs_delivery_time].nil?
      rescue Aws::CloudTrail::Errors::TrailNotFoundException
        nil
      end
    end
  end

  def logging?
    catch_aws_errors do
      begin
        @aws.cloudtrail_client.get_trail_status({ name: @trail_name }).to_h[:is_logging]
      rescue Aws::CloudTrail::Errors::TrailNotFoundException
        nil
      end
    end
  end

  def encrypted?
    !@kms_key_id.nil?
  end

  def get_log_group_for_multi_region_active_mgmt_rw_all
    return nil unless exists?
    return nil unless @cloud_watch_logs_log_group_arn
    return nil if @cloud_watch_logs_log_group_arn.split(":").count < 6
    return @cloud_watch_logs_log_group_arn.split(":")[6] if has_event_selector_mgmt_events_rw_type_all? && logging?
  end

  # TODO: see what happens when running against nil event selectors
  def has_event_selector_mgmt_events_rw_type_all?
    return nil unless exists?
    event_selector_found = false
    begin
      @event_selectors.event_selectors.each do |es|
        event_selector_found = true if es.read_write_type == "All" && es.include_management_events == true
      end
    rescue Aws::CloudTrail::Errors::TrailNotFoundException
      event_selector_found
    end
    event_selector_found
  end

  # describe aws_cloudtrail_trail(x) do
  #   it { should be_monitoring_read("arn::whatever::s3") }
  #   it { should be_monitoring_write("arn::whatever::s3") }
  #   it { should be_using_advanced_event_selectors }
  #   it { should be_using_basic_event_selectors }
  #   it { should be_multi_region_trail }
  # end

  def monitoring?(aws_resource_type, mode)
    if using_basic_event_selectors?
      basic_mode = mode == 'r' ? "ReadOnly" : "WriteOnly"
      @event_selectors.event_selectors.any? { |es|
        es.read_write_type.match?(/All|#{basic_mode}/) &&
        es.data_resources.any? { |dr|
          dr.values.include?(aws_resource_type)
        }
      }
    else
      advanced_mode = mode == 'r'
      @event_selectors.advanced_event_selectors.any? { |es|
        es.field_selectors.any? { |fs|

        }
      }
    end
  end

  def monitoring_read?(aws_resource_type)
    monitoring?(aws_resource_type, 'r')
  end

  def monitoring_write?(aws_resource_type)
    monitoring?(aws_resource_type, 'w')
  end

  def using_advanced_event_selectors?
    @event_selectors.advanced_event_selectors.present?
  end

  def using_basic_event_selectors?
    @event_selectors.event_selectors.present?
  end

  def exists?
    !@trail.nil? && !@trail.empty?
  end

  def to_s
    "CloudTrail #{@trail_name}"
  end
end
