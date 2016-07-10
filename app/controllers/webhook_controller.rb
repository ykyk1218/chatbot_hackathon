# reference: http://qiita.com/Arahabica/items/98e3d0d5b65269386dc4

class WebhookController < ApplicationController
  protect_from_forgery with: :null_session # CSRF対策無効化

  CHANNEL_ID = ENV['LINE_CHANNEL_ID']
  CHANNEL_SECRET = ENV['LINE_CHANNEL_SECRET']
  CHANNEL_MID = ENV['LINE_CHANNEL_MID']
  OUTBOUND_PROXY = ENV['LINE_OUTBOUND_PROXY']


  def callback
    unless is_validate_signature
      render :nothing => true, status: 470
    end
    result = params[:result][0]
    logger.info({from_line: result})
    client = LineClient.new(CHANNEL_ID, CHANNEL_SECRET, CHANNEL_MID, OUTBOUND_PROXY)

    # 友だちになった時(ブロック解除含む)
    if LineClient::EVENT_ID_OP == result['eventType'] \
      && LineClient::FREND_CONNECTION == result['content']['opType']
      first_communication result
    # ユーザーからメッセージ
    elsif LineClient::EVENT_ID_MSG == result['eventType']
      communication　result
    end

    render :nothing => true, status: :ok
  end



  # lunch時にメッセージ一斉送信 url : /lunch_cal?key=hogehoge123456
  def lunch_cal
    return unless params[:key] = "hogehoge123456"
    client = LineClient.new(CHANNEL_ID, CHANNEL_SECRET, CHANNEL_MID, OUTBOUND_PROXY)
    res = client.send(User.all.pluck(:line_mid), text_message)
    res_check res
    render :nothing => true, status: :ok
  end



  private
  def create_response_text(from_mid, user_text)
    conversation_log = ConversationLog.find_by(line_mid: from_mid).order('created_at DESC')
    message_text = conversation_log["message_text"]

    ActiveRecord::Base.transaction do
      user_conversation= ConversationLog.new(line_mid: from_mid, message_text: user_text)
      user_conversation.save

      if message_text == "hogehoge"
        response_text = "fugafuga"
        # message_textとresponse_textをDBに保存
      else
        response_text = "piyopiyo"

      end
      bot_conversation = ConversationLog.new(line_mid: 0000, message_text: response_text)
      bot_conversation.save
    end

      logger.info "会話ログの更新成功"
    rescue =>e
      response_text = e.mesage

    response_text
    
  end


  def proposal_lunch(category)
    # userlocalのapiを叩いて商品を検索して返す

  end


  # はじめまして + 最初の質問
  def first_communication result
    user_line_mid = result['from']
    user = User.find_or_create_by(line_mid: user_line_mid)

    
    first_send_msgs = MasterQuestion.where(id: 1..3)
    ress = []
    first_send_msgs.each do |q|
      ress.concat client.send([user_line_mid], q.question_text)
    end
    ress.each{|r| res_check r}
  end


  # ユーザーからのメッセージに対して返答
  def communication result
    user = User.find_by(line_mid: result['content']['from'])
    text_message = result['content']['text']

    # 会話ログをmidで検索して、更新日順にソートして1件目を取得
    response_text = create_response_text(user.line_mid, text_message)
    res = client.send([user.line_mid], response_text)
    res_check res
  end


  def res_check res
    if res.status == 200
      logger.info({success: res})
    else
      logger.info({fail: res})
    end
  end


  # LINEからのアクセスか確認.
  # 認証に成功すればtrueを返す。
  # ref) https://developers.line.me/bot-api/getting-started-with-bot-api-trial#signature_validation
  def is_validate_signature
    signature = request.headers["X-LINE-ChannelSignature"]
    http_request_body = request.raw_post
    hash = OpenSSL::HMAC::digest(OpenSSL::Digest::SHA256.new, CHANNEL_SECRET, http_request_body)
    signature_answer = Base64.strict_encode64(hash)
    signature == signature_answer
  end
end

