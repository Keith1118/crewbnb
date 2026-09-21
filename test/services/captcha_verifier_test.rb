require "test_helper"

# No test here reaches Cloudflare: every case is decided before the HTTP call.
class CaptchaVerifierTest < ActiveSupport::TestCase
  test "without keys there is no captcha to fail" do
    assert_not CaptchaVerifier.configured?
    assert CaptchaVerifier.passed?(nil)
  end

  test "once configured, a submission with no token is rejected" do
    stub_class_method(CaptchaVerifier, :configured?, true) do
      assert_not CaptchaVerifier.passed?(nil)
      assert_not CaptchaVerifier.passed?("")
    end
  end
end
