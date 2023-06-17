# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для модели Игры
# В идеале - все методы должны быть покрыты тестами,
# в этом классе содержится ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end


  # тесты на основную игровую логику
  context 'game mechanics' do
    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)
      game_w_questions.answer_current_question!(q.correct_answer_key)
      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end
  end

  context '#current game question & previous_level' do
    it 'returns the current game question' do
      game_w_questions.current_level = 10
      expect(game_w_questions.current_game_question).to be_instance_of(GameQuestion)
      expect(game_w_questions.current_game_question.level).to eq(10)
      expect(game_w_questions.current_game_question.level).to eq(game_w_questions.current_level)
    end

     it 'returns previous_level' do
      game_w_questions.current_level = 10
      expect(game_w_questions.previous_level).to eq 9
    end
  end

  describe '#answer_current_question!' do
    before { game_w_questions.answer_current_question!(answer_key) }

    context 'when answer is correct' do
      let!(:level) { 0 }
      let!(:answer_key) { game_w_questions.current_game_question.correct_answer_key }

      context 'and question is last' do
        let!(:level) { Question::QUESTION_LEVELS.max }
        let!(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user, current_level: level) }

        it 'assigns final prize' do
          expect(game_w_questions.prize).to eq(Game::PRIZES.max)
        end

        it 'finishes the game' do
          expect(game_w_questions.finished?).to be true
        end

        it 'finishes with status won' do
          expect(game_w_questions.status).to eq(:won)
        end

        it 'makes game not failed' do
          expect(game_w_questions.is_failed).to eq(false)
        end
      end

      context 'and question is not last' do
        it 'moves to next level' do
          expect(game_w_questions.current_level).to eq(level + 1)
        end

        it 'continues game' do
          expect(game_w_questions.finished?).to be false
        end

        it 'not change status' do
          expect(game_w_questions.status).to eq(:in_progress)
        end
      end

      context 'and time is over' do
        let!(:game_w_questions) { FactoryBot.create(:game_with_questions,
                                                     user: user,
                                                     current_level: level,
                                                     created_at: Game::TIME_LIMIT.minutes.ago) }

        it 'finishes the game' do
          expect(game_w_questions.finished?).to be true
        end

        it 'finishes with status timeout' do
          expect(game_w_questions.status).to eq(:timeout)
        end
      end
    end

    context 'when answer is wrong' do
      let!(:answer_key) { game_w_questions.current_game_question.a }

      it 'finishes the game' do
        expect(game_w_questions.finished?).to be true
      end

      it 'finishes with status fail' do
        expect(game_w_questions.status).to eq(:fail)
      end
    end
  end

  describe '#take_money' do
    before { game_w_questions.take_money! }
    let!(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user, current_level: 5) }

    it 'makes prize bigger then 0' do
      expect(game_w_questions.prize).to be > 0
    end

    it 'finishes the game' do
      expect(game_w_questions.finished?).to be true
    end

    it 'finishes with status money' do
      expect(game_w_questions.status).to eq(:money)
    end

    it 'increases the user balance' do
      expect(user.balance).to eq(game_w_questions.prize)
    end
  end

  describe '#status' do
    context 'when game not finished' do
      it 'returns in_progress' do
        expect(game_w_questions.status).to eq :in_progress
        expect(game_w_questions.finished_at).to be nil
      end
    end

    context 'when game is finished' do
      before(:each) do
        game_w_questions.finished_at = Time.now
        expect(game_w_questions.finished?).to be true
      end

      context 'and game is failed' do
        it 'returns fail' do
          game_w_questions.is_failed = true
          expect(game_w_questions.status).to eq(:fail)
        end
      end

      context 'and level bigger then max' do
        it 'returns won' do
          game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
          expect(game_w_questions.status).to eq(:won)
        end
      end

      context 'and time has passed' do
        it 'returns timeout' do
          game_w_questions.created_at = Game::TIME_LIMIT.minutes.ago
          game_w_questions.is_failed = true
          expect(game_w_questions.status).to eq(:timeout)
        end
      end

      context 'and user took money' do
        it 'returns money' do
          game_w_questions.take_money!
          expect(game_w_questions.status).to eq(:money)
        end
      end
    end
  end

  context '#take money!' do
    it 'returns the answer current question' do
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)
      game_w_questions.take_money!
      prize = game_w_questions.prize
      expect(prize).to be > 0
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be true
      expect(user.balance).to eq prize
    end
  end

  # группа тестов на проверку статуса игры
  context '.status' do
    # перед каждым тестом "завершаем игру"
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it ':won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it ':timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it ':money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end
end
