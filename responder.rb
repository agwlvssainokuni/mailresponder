#!/usr/bin/ruby
# -*- coding: utf-8 -*-
#
#  Copyright 2012 Norio Agawa
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

require 'yaml'
require 'optparse'
require 'rubygems'
require 'action_mailer'

app_root = File.dirname(File.expand_path(__FILE__))
TMail.instance_eval { remove_const 'Parser' }
require app_root + '/lib/tmail_parser.rb'
require app_root + '/lib/actionmailer_ja.rb'


Version = '1.0.0'

# [処理概要]
# (0) メール送信の実体 (ActionMailer::Baseの子クラス) を定義
# (1) コマンドライン引数を解析する
# (2) 引数で指定された定義を読込む
# (3) 受信したメールを解析する
# (4) メールを処理する (メールから埋込みデータを生成する)
# (5) メールを配信する


# (0) メール送信の実体 (ActionMailer::Baseの子クラス) を定義
class Responder < ActionMailer::Base
  def response(addr, conf, mail, param)
    recipients	addr
    subject	conf['subject']
    from	conf['from']
    bcc		conf['bcc'] if conf['bcc']
    sent_on	Time.now
    template	conf['template']
    body	:addr => addr, :conf => conf, :mail => mail, :param => param
  end
end

Responder.template_root = app_root
Responder.delivery_method = :sendmail
Responder.raise_delivery_errors = true


# (1) コマンドライン引数を解析する
PARAM = {
  :addr => nil,
  :conf => nil,
  :filter => app_root + '/filter/empty.rb',
  :verbose => false,
  :deliver => false
}

opt = OptionParser.new
opt.on('-a ADDR', '--addr ADDR') {|p| PARAM[:addr] = p }
opt.on('-c CONF', '--conf CONF') {|p| PARAM[:conf] = p }
opt.on('-f FILTER', '--filter FILTER') {|p| PARAM[:filter] = p }
opt.on('--[no-]verbose') {|p| PARAM[:verbose] = p }
opt.on('--[no-]deliver') {|p| PARAM[:deliver] = p }
opt.parse!(ARGV)

if PARAM[:verbose]
  printf("APP_ROOT = %s\n", app_root)
  printf("PARAM[:addr] = %s\n", PARAM[:addr]) if PARAM[:addr]
  printf("PARAM[:conf] = %s\n", PARAM[:conf])
  printf("PARAM[:filter] = %s\n", PARAM[:filter])
  printf("PARAM[:verbose] = %s\n", PARAM[:verbose])
  printf("PARAM[:deliver] = %s\n", PARAM[:deliver])
end


# (2) 引数で指定された定義を読込む
require PARAM[:filter]
conf = YAML.load_file(PARAM[:conf]) if PARAM[:conf]


# (3) 受信したメールを解析する
unless PARAM[:addr]

  text = readlines(nil)
  if PARAM[:verbose]
    print("MAIL(text) BELOW\n")
    print(text[0])
    print("MAIL(text) ABOVE\n")
  end

  mail = TMail::Mail.parse(text[0])
  if PARAM[:verbose]
    print("MAIL(parsed) BELOW\n")
    print(mail.encoded)
    print("MAIL(parsed) ABOVE\n")
  end

  if mail.from.size == 1
    PARAM[:addr] = mail.from[0]
  else
    PARAM[:addr] = mail.sender
  end

  if PARAM[:verbose]
    printf("PARAM[:addr] = %s\n", PARAM[:addr])
  end
end


# (4) メールを処理する (メールから埋込みデータを生成する)
param = do_filter(PARAM[:addr], conf, mail)


# (5) メールを配信する
unless PARAM[:deliver]
  m = Responder.create_response(PARAM[:addr], conf, mail, param)
  print("CREATED MESSAGE BEGIN\n")
  print m.encoded
  print("CREATED MESSAGE END\n")
else
  m = Responder.deliver_response(PARAM[:addr], conf, mail, param)
  if PARAM[:verbose]
    print("DELIVERED MESSAGE BEGIN\n")
    print m.encoded
    print("DELIVERED MESSAGE END\n")
  end
end
