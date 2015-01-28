class ItemController < ApplicationController
  def index
    @items = Item.all
    @items = @items.where(delivered_at: nil) if params[:undelivered] == "true"
    render json: @items
  end
end
