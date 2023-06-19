#  (c) goodprogrammer.ru
#
# Класс, генерирующий подсказки по игре для поля GameQuestion#help_hash
class GameHelpGenerator
  # сколько всего виртуальных зрителей в игре (в процентах получается)
  TOTAL_WATCHERS = 100
  MIN_PROBABILITY = 80

  class << self
    # Возвращает hash c массивом ключей keys и значениями - распределением в процентах
    # correct_key - ключ правильного ответа, он будет выбран с бОльшим весом
    def audience_distribution(keys, correct_key)
      result_array = keys.map do |key|
        if key == correct_key
          rand(45..90)
        else
          rand(1..60)
        end
      end

      # нормализуем массив
      sum = result_array.sum
      result_array.map! { |v| TOTAL_WATCHERS * v / sum }

      # возвращаем хэш, собранный из массива ключей и значений (см. доку на метод Array#zip)
      Hash[keys.zip(result_array)]
    end

    # Возвращает строку подсказки: что советует друг
    # correct_key - ключ правильного ответа, он будет выбран с бОльшим весом
    def friend_call(keys, correct_key)
      # c ~80% вероятностью выбираем правильный ключ, и с 20% - неправильный
      key = correct_key
      key = keys.grep_v(correct_key).sample if random_of_hundred > MIN_PROBABILITY

      I18n.t('game_help.friend_call', name: I18n.t('game_help.friends').sample, variant: key.upcase)
    end

    private

    def random_of_hundred
      rand(1..100)
    end
  end
end
