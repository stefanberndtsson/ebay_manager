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
      @item.mark_as_delivered
    end
  end
end
