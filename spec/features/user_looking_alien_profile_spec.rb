# Как и в любом тесте, подключаем помощник rspec-rails
require 'rails_helper'

# Начинаем описывать функционал, связанный с созданием игры
RSpec.feature 'USER looking alien profile', type: :feature do
  let!(:first_user) { FactoryBot.create :user }
  let!(:second_user) { FactoryBot.create :user }
  let!(:game_w_questions) { FactoryBot.create(:game_with_questions, user: first_user) }

  before { login_as second_user }

  scenario 'successfully' do
    visit '/'

    click_link first_user.name

    expect(page).to have_current_path '/users/1'

    expect(page).to have_content first_user.name

    expect(page).to have_content 'Дата'
    expect(page).to have_content 'Вопрос'
    expect(page).to have_content 'Выигрыш'
    expect(page).to have_content 'Подсказки'

    expect(page).not_to have_content 'Сменить имя и пароль'
  end
end
