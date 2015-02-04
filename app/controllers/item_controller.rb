class ItemController < ApplicationController
  respond_to :html, :json

  def index
    @items = Item.all
    @items = @items.where(delivered_at: nil) if params[:undelivered] == "true"
    respond_with(@items)
  end

  def show
    @item = Item.find(params[:id])
    respond_with(@item)
  end
end
