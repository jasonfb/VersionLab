# Helper for setting React-controlled input values in Capybara/Selenium specs.
# React ignores programmatic value changes unless the native setter + input event is used.
module ReactHelpers
  def react_fill_in(element, with:)
    page.execute_script(<<~JS, element.native, with)
      var el = arguments[0];
      var value = arguments[1];
      var nativeSetter = Object.getOwnPropertyDescriptor(
        window.HTMLInputElement.prototype, 'value'
      ).set;
      nativeSetter.call(el, value);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    JS
  end

  def react_fill_in_textarea(element, with:)
    page.execute_script(<<~JS, element.native, with)
      var el = arguments[0];
      var value = arguments[1];
      var nativeSetter = Object.getOwnPropertyDescriptor(
        window.HTMLTextAreaElement.prototype, 'value'
      ).set;
      nativeSetter.call(el, value);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    JS
  end
end

RSpec.configure do |config|
  config.include ReactHelpers, type: :feature
end
