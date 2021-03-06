class TransactionsController < ApplicationController
  require "payjp"
  before_action :move_to_sign_in
  before_action :move_to_sold
  before_action :set_item_to_session, only: :new
  before_action :set_card, only: [:new, :create]
 

  def new
    @transaction = Transaction.new

    # 対象の商品を取得
    @item = Item.find(params[:item_id])

    @address = Address.find_by(user_id: current_user.id)
   
    # 現在のユーザーがカードを登録済みの場合、カードの情報（payjp）を取得する
    if @card
      # 秘密鍵を設定
      Payjp.api_key = ENV["PAYJP_PRIVATE_KEY"]

      # 所有者を取得
      customer = Payjp::Customer.retrieve(@card.customer_id)

      # 所有者に紐づくカードIDから、idを指定してカード情報（payjp）を取得する
      @card_payjp = customer.cards.retrieve(@card.card_id)
    end
  end

  def create
    # 現在のユーザーのカード情報を取得（1ユーザーにつき、カードは1枚のみの想定）
    transaction = Transaction.new(buyer_id: current_user.id,
                                  card_id: @card.id,
                                  item_id: params[:item_id],
                                  status: 0)
    if transaction.save

      # 決済処理
      Payjp.api_key = ENV["PAYJP_PRIVATE_KEY"]
      
      # 支払い情報を設定
      Payjp::Charge.create(
        # 金額
        amount: Item.find(params[:item_id]).price,
        # payjpが管理する顧客ID
        :customer => @card.customer_id,
        # 日本円
        currency: 'jpy'
      )
      
      # セッションの商品IDを削除する
      session.delete(:item_id)

      # 登録成功の場合、トップページへ遷移する
      redirect_to controller: 'items', action: 'index', notice: '商品を購入しました'
    else
      # 登録失敗の場合、購入確認画面へ戻る
      render action: 'new'
    end
  end

  private
  # セッションに商品IDを設定する
  def set_item_to_session
    session[:item_id] = params[:item_id]
  end

  # 現在のユーザーのカードを取得する
  def set_card
    @card = current_user.card
  end

  def move_to_sign_in
    redirect_to new_user_session_path unless user_signed_in?
  end

  def move_to_sold
    item = Item.find(params[:item_id])
    sold = Transaction.find_by(item_id: item.id)  
    redirect_to item_path(item.id) if sold != nil || item.seller_id == current_user.id   
  end
end