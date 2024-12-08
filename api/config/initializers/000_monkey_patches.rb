# frozen_string_literal: true

# https://techlife.cookpad.com/entry/a-guide-to-monkey-patchers
# 基本的にはrefineを使う

Rails.root.glob('lib/monkey_patches/**/*.rb')
  .each {|file| require file }
