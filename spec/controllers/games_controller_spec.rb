# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера (Анонимус)
  describe '#show' do
    # из экшена show анона посылаем
    context 'anon kick from #show' do
      before { get :show, id: game_w_questions.id } # вызываем экшен

      it 'check status' do
        expect(response.status).not_to eq(200) # статус не 200 ОК
      end

      it 'redirect to login' do
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      end

      it 'must be error' do
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  describe 'usual user' do
    # перед каждым тестом в группе
    before { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    # юзер может создать новую игру
    context 'creates game' do
      before { sign_in user }
      before { generate_questions(15) } # накидаем вопросов
      before { post :create }

      let!(:game) { assigns(:game) } # вытаскиваем из контроллера поле @game

      it 'check game status' do
        # проверяем состояние этой игры
        expect(game.finished?).to be false
      end

      it 'check game user' do
        expect(game.user).to eq(user)
      end

      it 'redirect to game page' do
        # редирект на страницу этой игры
        expect(response).to redirect_to(game_path(game))
      end

      it 'show flash' do
        expect(flash[:notice]).to be
      end
    end

    # юзер видит свою игру
    context 'see game' do
      before { get :show, id: game_w_questions.id }
      let!(:game) { assigns(:game) } # вытаскиваем из контроллера поле @game

      it 'game not finish' do
        expect(game.finished?).to be false
      end

      it 'check game user' do
        expect(game.user).to eq(user)
      end

      it 'check status' do
        expect(response.status).to eq(200) # должен быть ответ HTTP 200
      end

      it 'redirect to template show' do
        expect(response).to render_template('show') # и отрендерить шаблон show
      end
    end

    # юзер отвечает на игру корректно - игра продолжается
    context 'answers correct on game questions' do
      before { put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key }
      let!(:game) { assigns(:game) } # вытаскиваем из контроллера поле @game

      it 'game not finish' do
        expect(game.finished?).to be false
      end

      it 'game level up' do
        expect(game.current_level).to be > 0
      end

      it 'game continues' do
        expect(response).to redirect_to(game_path(game))
      end

      it 'successful response does not fill flash' do
        expect(flash.empty?).to be true # удачный ответ не заполняет flash
      end
    end

    # тест на отработку "помощи зала"
    context 'may use hints' do
      it 'use audience help' do
        # сперва проверяем что в подсказках текущего вопроса пусто
        expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
        expect(game_w_questions.audience_help_used).to be false

        # фигачим запрос в контроллен с нужным типом
        put :help, id: game_w_questions.id, help_type: :audience_help
        game = assigns(:game)

        # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
        expect(game.finished?).to be false
        expect(game.audience_help_used).to be true
        expect(game.current_game_question.help_hash[:audience_help]).to be
        expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
        expect(response).to redirect_to(game_path(game))
      end

      it 'use fifty fifty help' do
        # сперва проверяем что в подсказках текущего вопроса пусто
        expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
        expect(game_w_questions.fifty_fifty_used).to be false

        # фигачим запрос в контроллен с нужным типом
        put :help, id: game_w_questions.id, help_type: :fifty_fifty
        game = assigns(:game)

        # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
        expect(game.finished?).to be false
        expect(game.fifty_fifty_used).to be true
        expect(game.current_game_question.help_hash[:fifty_fifty]).to be
        expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq 2
        expect(response).to redirect_to(game_path(game))
      end
    end

    context 'kick from other game' do
      let!(:alien_game) { FactoryBot.create(:game_with_questions) }
      before { get :show, id: alien_game.id }

      it 'response not OK' do
        expect(response.status).not_to eq(200) # статус не 200 ОК
      end

      it 'redirect to main page' do
        expect(response).to redirect_to(root_path)
      end

      it 'show flash' do
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end

    context '#takes money' do
      before { game_w_questions.update_attribute(:current_level, 2) }
      before { put :take_money, id: game_w_questions.id }

      let!(:game) { assigns(:game) } # вытаскиваем из контроллера поле @game

      it 'user takes money until the game finish' do
        expect(game.finished?).to be true
        expect(game.prize).to eq(200)
        # пользователь изменился в базе, надо в коде перезагрузить!
        user.reload
        expect(user.balance).to eq(200)
        expect(response).to redirect_to(user_path(user))
        expect(flash[:warning]).to be
      end
    end

    context 'start second game' do
      it 'user cannot start two games' do
        # убедились что есть игра в работе
        expect(game_w_questions.finished?).to be false
        # отправляем запрос на создание, убеждаемся что новых Game не создалось
        expect { post :create }.to change(Game, :count).by(0)
        game = assigns(:game) # вытаскиваем из контроллера поле @game
        expect(game).to be_nil
        # и редирект на страницу старой игры
        expect(response).to redirect_to(game_path(game_w_questions))
        expect(flash[:alert]).to be
      end
    end

    context 'user wrong answer' do
      before do
        put :answer,
            id: game_w_questions.id,
            letter: %w[a b c d].grep_v(game_w_questions.current_game_question.correct_answer_key).sample
      end

      let!(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user, current_level: Game::FIREPROOF_LEVELS[0] + 1) }
      let!(:game) { assigns(:game) }

      it 'if user give wrong answer' do
        expect(game.finished?).to be true
        expect(response).to redirect_to(user_path(user))
        expect(flash[:alert]).to be
        expect(game.prize).to eq(Game::PRIZES[Game::FIREPROOF_LEVELS[0]])
        user.reload
        expect(user.balance).to eq(Game::PRIZES[Game::FIREPROOF_LEVELS[0]])
      end
    end
  end
end
