# coding: utf-8
require 'mecab'

c = MeCab::Tagger.new()
parsed = c.parse("日本語の文章です")
print parsed










