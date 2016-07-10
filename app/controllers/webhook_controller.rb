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
      user_line_mid = result['from']
      user = User.find_or_create_by(line_mid: user_line_mid)

      # はじめまして 等
      first_send_msgs = MasterQuestion.where(id: 1..3)
      ress = []
      first_send_msgs.each do |q|
        ress.concat client.send([user.line_mid], q.question_text)
      end
      ress.each{|r| res_check r}


    # ユーザーからメッセージ
    elsif LineClient::EVENT_ID_MSG == result['eventType']
      user = User.find_by(line_mid: result['content']['from'])

      # 直前の質問 * 回答
      text_message = result['content']['text']
      # 返答
      res = client.send([user.line_mid], text_message)
      res_check res
    end


    render :nothing => true, status: :ok
  end

  private
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

  def res_check res
    if res.status == 200
      logger.info({success: res})
    else
      logger.info({fail: res})
    end
  end
end

