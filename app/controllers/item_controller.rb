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

  def update
    @item = Item.find(params[:id])
    if @params[:mark_as_delivered]
      delivery_date = params[:delivered_at]
      @item.mark_as_delivered(delivery_date)
    end
  end
end
