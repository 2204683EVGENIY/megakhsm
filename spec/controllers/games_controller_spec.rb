# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер

RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }
  # вытаскиваем поле game из контроллера
  let(:game) { assigns(:game) }

  # тесты на метод #show
  describe '#show' do
    # юзер не залогинен
    context 'user is not login' do
      before { get :show, id: game_w_questions.id }

      it 'check status' do
        expect(response.status).not_to eq(200)
      end

      it 'redirect to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'must be error' do
        expect(flash[:alert]).to be
      end
    end

    # юзер залогинен
    context 'user is login' do
      # перед каждым тестом в группе
      before { sign_in user }

      # юзер видит свою игру
      context 'user see game' do
        before { get :show, id: game_w_questions.id }

        it 'game not finish' do
          expect(game.finished?).to be false
        end

        it 'check game user' do
          expect(game.user).to eq(user)
        end

        it 'check status' do
          expect(response.status).to eq(200) # должен быть ответ HTTP 200
        end

        it 'redirect to show' do
          expect(response).to render_template('show') # и отрендерить шаблон show
        end
      end

      # юзер не видит свою игру
      context 'user not see game' do
        before { get :show, id: alien_game.id }
        let!(:alien_game) { create(:game_with_questions) }

        it 'redirects from show' do
          expect(response).to redirect_to(root_path)
        end

        it 'check status' do
          expect(response.status).not_to eq(200)
        end

        it 'show flash' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  # тесты на метод #create
  describe '#create' do
    before { generate_questions(15) }
    before { post :create }

    # юзер не залогинен
    context 'user is not login' do
      let(:create_game) { post :create }

      it 'does not create new game' do
        expect { create_game }.to change(Game, :count).by(0)
      end

      it 'game nil' do
        expect(game).to be_nil
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'show flash' do
        expect(flash[:alert]).to be
      end

      it 'check status' do
        expect(response.status).not_to eq(200)
      end
    end

    # юзер залогинен
    context 'user is login' do
      before { sign_in user }

      # юзер создает игру и у него нет незаконченных игр
      context 'user create game and no have active games' do
        before { post :create }

        it 'check game status' do
          expect(game.finished?).to be false
        end

        it 'check game user' do
          expect(game.user).to eq(user)
        end

        it 'redirect to game page' do
          expect(response).to redirect_to(game_path(game))
        end

        it 'show flash' do
          expect(flash[:notice]).to be
        end
      end

      # юзер создает игру и у него есть незаконченная игра
      context 'user create game and have active games' do
        before { game_w_questions }
        let!(:create_game) { post :create }

        it 'old game did not finish' do
          expect(game_w_questions.finished?).to be false
        end

        it 'expect new game does not start' do
          expect { create_game }.to change(Game, :count).by(0)
        end

        it 'expect game is nil' do
          expect(game).to be_nil
        end

        it 'redirects to old game' do
          expect(response).to redirect_to(game_path(game_w_questions))
        end

        it 'show flash' do
          expect(flash[:alert]).to be
        end
      end
    end
  end

  # тесты на метод #answer
  describe '#answer' do

    # юзер не залогинен
    context 'user is not login' do
      before { put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key }

      it 'sets game nil' do
        expect(game).to be_nil
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'show flash' do
        expect(flash[:alert]).to be
      end

      it 'sets response status not 200' do
        expect(response.status).not_to eq(200)
      end
    end

    # юзер залогинен
    context 'user login' do
      before { sign_in user }

      # правильный ответ
      context 'answer is correct' do
        before { put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key }

        it 'does not finish game' do
          expect(game.finished?).to be false
        end

        it 'sets next level' do
          expect(game.current_level).to eq(1)
        end

        it 'redirects to game' do
          expect(response).to redirect_to(game_path(game))
        end

        it 'does not show flash' do
          expect(flash.empty?).to be true
        end
      end

      # неправильный ответ
      context 'answer is wrong' do
        let!(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user, current_level: Game::FIREPROOF_LEVELS[1]) }

        before do
          put :answer,
              id: game_w_questions.id,
              letter: %w[a b c d].grep_v(game_w_questions.current_game_question.correct_answer_key).sample
        end

        it 'finishes game' do
          expect(game.finished?).to be true
        end

        it 'redirects to user' do
          expect(response).to redirect_to(user_path(user))
        end

        it 'show flash' do
          expect(flash[:alert]).to be
        end

        it 'sets prize' do
          expect(game.prize).to eq(Game::PRIZES[Game::FIREPROOF_LEVELS[0]])
        end

        it 'updates user balance' do
          user.reload
          expect(user.balance).to eq(Game::PRIZES[Game::FIREPROOF_LEVELS[0]])
        end
      end
    end
  end

  # тесты на метод #help
  describe '#help' do
    # юзер не залогинен
    context 'when user is not signed in' do
      # юзер пытается получить любую помощь
      context 'try use any help' do
        before { put :help, id: game_w_questions.id, help_type: :audience_help }

        it 'game nil' do
          expect(game).to be_nil
        end

        it 'redirects to login' do
          expect(response).to redirect_to(new_user_session_path)
        end

        it 'show flash' do
          expect(flash[:alert]).to be
        end

        it 'sets response status not 200' do
          expect(response.status).not_to eq(200)
        end
      end
    end

    # юзер не залогинен
    context 'when user is signed in' do
      before { sign_in user }

      # использует подсказку помощь зала
      context 'use audience help' do
        before { put :help, id: game_w_questions.id, help_type: :audience_help }

        it 'does not finish game' do
          expect(game.finished?).to be false
        end

        it 'toggles audience help_used' do
          expect(game.audience_help_used).to be true
        end

        it 'adds audience help to help hash' do
          expect(game.current_game_question.help_hash[:audience_help]).to be
        end

        it 'redirects to game' do
          expect(response).to redirect_to(game_path(game))
        end

        it 'returns all keys' do
          expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
        end

        it 'show flash' do
          expect(flash[:info]).to be
        end
      end

      # использует подсказку 50/50
      context 'use fifty fifty help' do
        before { put :help, id: game_w_questions.id, help_type: :fifty_fifty }

        it 'does not finish game' do
          expect(game.finished?).to be false
        end

        it 'toggles fifty fifty used' do
          expect(game.fifty_fifty_used).to be true
        end

        it 'adds fifty fifty to help hash' do
          expect(game.current_game_question.help_hash[:fifty_fifty]).to be
        end

        it 'redirects to game' do
          expect(response).to redirect_to(game_path(game))
        end

        it 'returns array with 2 elements' do
          expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq(2)
        end

        it 'includes correct answer key' do
          expect(game.current_game_question.help_hash[:fifty_fifty]).to include(game.current_game_question.correct_answer_key)
        end

        it 'show flash' do
          expect(flash[:info]).to be
        end
      end

      # использует подсказку звонок другу
      context 'and use friend call help' do
        before { put :help, id: game_w_questions.id, help_type: :friend_call }

        it 'does not finish game' do
          expect(game.finished?).to be false
        end

        it 'toggles friend call_used' do
          expect(game.friend_call_used).to be true
        end

        it 'adds friend call to help hash' do
          expect(game.current_game_question.help_hash[:friend_call]).to be
        end

        it 'redirects to game' do
          expect(response).to redirect_to(game_path(game))
        end

        it 'returns string' do
          expect(game.current_game_question.help_hash[:friend_call]).to be_instance_of(String)
        end

        it 'show flash' do
          expect(flash[:info]).to be
        end
      end
    end
  end

  # тесты на метод #take money!
  describe '#take_money' do
    before { game_w_questions.update_attribute(:current_level, 2) }

    # юзер не залогинен
    context 'user is not signed in' do
      before { put :take_money, id: game_w_questions.id }

      it 'sets game nil' do
        expect(game).to be_nil
      end

      it 'redirects to login' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'show flash' do
        expect(flash[:alert]).to be
      end

      it 'response status not 200' do
        expect(response.status).not_to eq(200)
      end
    end

    # юзер залогинен
    context 'user signed in' do
      before { sign_in user }
      before { put :take_money, id: game_w_questions.id }

      it 'show flash' do
        expect(flash[:warning]).to be
      end

      it 'redirects to user page' do
        expect(response).to redirect_to(user_path(user))
      end

      it 'finish game' do
        expect(game.finished?).to be true
      end

      it 'get prize' do
        expect(game.prize).to eq(200)
      end

      it 'update user balance' do
        user.reload
        expect(user.balance).to eq(200)
      end
    end
  end
end
