class BankrollsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bankroll

  def show
    @recent_transactions = @bankroll.transaction_history(limit: 10)
  end

  def deposit
    amount = params[:amount].to_f

    if amount <= 0
      flash[:alert] = "Deposit amount must be greater than $0"
      redirect_to bankroll_path and return
    end

    result = @bankroll.deposit(amount)

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:alert] = result[:message]
    end

    redirect_to bankroll_path
  end

  def withdraw
    amount = params[:amount].to_f

    if amount <= 0
      flash[:alert] = "Withdrawal amount must be greater than $0"
      redirect_to bankroll_path and return
    end

    result = @bankroll.withdraw(amount)

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:alert] = result[:message]
    end

    redirect_to bankroll_path
  end

  private

  def set_bankroll
    @bankroll = current_user.bankroll
    redirect_to root_path, alert: "Bankroll not found" unless @bankroll
  end
end
