require 'rails_helper'

RSpec.describe 'users/show', type: :view do
  let!(:gamer) { FactoryBot.create(:user, name: 'Вадик') }

  before(:each) do
    assign(:user, gamer)
    assign(:games, [build_stubbed(:game)])
    stub_template 'users/_game.html.erb' => 'All user`s games'
  end

  context 'when user signed in' do
    context 'alien account' do
      let!(:not_owner) { FactoryBot.build_stubbed(:user, name: 'Миша') }
      before { sign_in not_owner }
      before { render }

      it 'renders gamer names' do
        expect(rendered).to match 'Вадик'
      end

      it 'does not renders link to edit account' do
        expect(rendered).not_to match 'Сменить имя и пароль'
      end

      it 'renders game' do
        expect(rendered).to have_content 'All user`s games'
      end
    end

    context 'master account' do
      before { sign_in gamer }
      before { render }

      it 'renders player names' do
        expect(rendered).to match 'Вадик'
      end

      it 'renders link to edit account' do
        expect(rendered).to match 'Сменить имя и пароль'
      end

      it 'renders game' do
        expect(rendered).to have_content 'All user`s games'
      end
    end
  end
end
