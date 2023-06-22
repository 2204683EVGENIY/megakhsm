# Как и в любом тесте, подключаем помощник rspec-rails
require 'rails_helper'

# Начинаем описывать функционал, связанный с созданием игры
RSpec.feature 'USER looking alien profile', type: :feature do
  let!(:first_user) { FactoryBot.create :user }
  let!(:second_user) { FactoryBot.create :user }
  let!(:game_w_questions) { FactoryBot.create(:game_with_questions, user: first_user, current_level: 5, created_at: Time.zone.parse('2012.12.12, 12:00')) }

  before { game_w_questions.take_money! }
  before { login_as second_user }

  scenario 'successfully' do
    visit '/'

    click_link first_user.name

    expect(page).to have_current_path "/users/#{game_w_questions.user.id}"

    expect(page).to have_content first_user.name

    expect(page).to have_content 'Выйти'
    expect(page).to have_content 'Новая игра'
    expect(page).to have_content(first_user.name)
    expect(page).to have_content(game_w_questions.user.name)
    expect(page).to have_content(game_w_questions.current_level)
    expect(page).to have_content(game_w_questions.id)
    expect(page).to have_content 'Дата'
    expect(page).to have_content '12 дек., 12:00'
    expect(page).to have_content '50/50'
    expect(page).to have_content 'время'
    expect(page).to have_content 'Вопрос'
    expect(page).to have_content 'Выигрыш'
    expect(page).to have_content 'Подсказки'

    expect(page).not_to have_content 'Сменить имя и пароль'

    save_and_open_page
  end
end
