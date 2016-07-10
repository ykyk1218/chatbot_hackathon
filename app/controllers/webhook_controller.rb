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


    # 新規登録の場合――――――――――――――――――――――――
    # ユーザー属性を確認してuser テーブルに保存


    # ユーザーから返信の場合――――――――――――――――――――――――

    text_message = result['content']['text']
    from_mid =result['content']['from']

    # 直前の質問 * 回答
    #
    # 会話ログをmidで検索して、更新日順にソートして1件目を取得
    response_text = create_response_text(from_mid, text_message)
     
    # 返答
    client = LineClient.new(CHANNEL_ID, CHANNEL_SECRET, CHANNEL_MID, OUTBOUND_PROXY)
    res = client.send([from_mid], response_text)

    if res.status == 200
      logger.info({success: res})
    else
      logger.info({fail: res})
    end
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
    end

    response_text
    
  end

  def proposal_lunch(category)
    # userlocalのapiを叩いて商品を検索して返す

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
