require 'helper'
require 'aws_elasticloadbalancingv2_listener_certificates'
require 'aws-sdk-core'

class AWSElasticLoadBalancingV2ListenerCertificatesConstructorTest < Minitest::Test

  def test_empty_params_ok
    AWSElasticLoadBalancingV2ListenerCertificates.new(listener_arn: 'test1', client_args: { stub_responses: true })
  end

  def test_rejects_other_args
    assert_raises(ArgumentError) { AWSElasticLoadBalancingV2ListenerCertificates.new('rubbish') }
  end

  def test_work_groups_non_existing_for_empty_response
    refute AWSElasticLoadBalancingV2ListenerCertificates.new(listener_arn: 'test1', client_args: { stub_responses: true }).exist?
  end
end

class AWSElasticLoadBalancingV2ListenerCertificatesHappyPathTest < Minitest::Test

  def setup
    data = {}
    data[:method] = :describe_listener_certificates
    mock_data = {}
    mock_data[:certificate_arn] = 'test1'
    mock_data[:is_default] = true
    data[:data] = { :certificates => [mock_data] }
    data[:client] = Aws::ElasticLoadBalancingV2::Client
    @certificates = AWSElasticLoadBalancingV2ListenerCertificates.new(listener_arn: 'test1', client_args: { stub_responses: true }, stub_data: [data])
  end

  def test_certificates_exists
    assert @certificates.exist?
  end

  def test_certificate_arns
    assert_equal(@certificates.certificate_arns, ['test1'])
  end

  def test_is_defaults
    assert_equal(@certificates.is_defaults, [true])
  end

  def test_resource_id
    refute_nil(@certificates.resource_id)
    assert_equal(@certificates.resource_id, 'test1')
  end

end