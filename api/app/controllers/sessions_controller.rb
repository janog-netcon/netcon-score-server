# frozen_string_literal: true

class SessionsController < ApplicationController
  before_action :require_login, only: %i[current logout]

  def current
    render json: build_current_team_response(current_team), status: :ok
  end

  def login
    team = Team.login(name: login_params[:name], password: login_params[:password])

    if team
      # protect session fixation attack
      reset_session

      # 以降のリクエストではこれからcurrent_teamをもとめる
      session[:team_id] = team.id

      # セッション管理用に記録する
      session[:created_at] = Time.current
      update_session_info

      # Sentryなどでのデバッグ用
      # ログイン後に更新される可能性があるので参考程度にする
      session[:team_name] = team.name
      session[:team_role] = team.role
      session[:channel] = team.channel

      render json: build_current_team_response(team), status: :ok
    else
      head :bad_request
    end
  end

  # 動的にTeamを作成しない前提で設計したのでいろいろガタガタ
  def signup
    if Config.registration_code != signup_params[:registrationCode]
      head :forbidden
      return
    end

    # TODO: autoincrementにしたほうが良い
    number = SecureRandom.random_number(2_147_483_647)

    team = Team.new(
      number: number,
      name: signup_params[:name],
      password: signup_params[:password],
      organization: signup_params[:organization],
      role: :player,
      color: '#FFFFFF',
      beginner: false,
      secret_text: ''
    )

    # 無いよりマシ程度だがnameとnumberのユニークバリデーションも行われる
    if team.save
      head :created
      return
    end

    error_reasons = team.errors.details.values.flatten.pluck(:error).uniq

    # nameかnumberがコンフリクトした
    if error_reasons.include?(:taken)
      render json: team.errors.to_json, status: :conflict
      return
    end

    # 謎の失敗
    render json: team.errors.to_json, status: :bad_request
  end

  def logout
    reset_session
    head :no_content
  end

  private

  def login_params
    # wrap_parameter
    params.require(:session).permit(:name, :password)
  end

  def signup_params
    params.require(:session).permit(:name, :password, :organization, :registrationCode)
  end

  # 必要な値だけ返す
  def build_current_team_response(team)
    # role: UI側で表示切り替えに使われる
    # channels: 非同期通知用チャンネル
    { id: team.id, role: team.role, channels: PlasmaPush.select_listen_channels(team: team) }
  end
end
