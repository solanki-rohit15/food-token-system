FactoryBot.define do
    factory :food_item do
      category   { "lunch" }
      active     { true }
      sort_order { 1 }
    end
  end