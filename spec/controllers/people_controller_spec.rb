#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe PeopleController do
  render_views

  before do
    @user   = alice
    @aspect = @user.aspects.first
    sign_in :user, @user
  end

  describe '#index (search)' do
    before do
      @eugene = Factory.create(:person,
        :profile => Factory.build(:profile, :first_name => "Eugene",
                     :last_name => "w"))
      @korth  = Factory.create(:person,
        :profile => Factory.build(:profile, :first_name => "Evan",
                     :last_name => "Korth"))
    end

    it 'responds with json' do
      get :index, :q => "Korth", :format => 'json'
      response.body.should == [@korth].to_json
    end
    it 'does not set @hashes in a json request' do
      get :index, :q => "Korth", :format => 'json'
      assigns[:hashes].should be_nil
    end
    it 'sets @hashes in an html request' do
      get :index, :q => "Korth"
      assigns[:hashes].should_not be_nil
    end
    it "assigns people" do
      eugene2 = Factory.create(:person,
        :profile => Factory.build(:profile, :first_name => "Eugene",
                     :last_name => "w"))
      get :index, :q => "Eug"
      assigns[:people].should =~ [@eugene, eugene2]
    end

    it "does not redirect to person page if there is exactly one match" do
      get :index, :q => "Korth"
      response.should_not redirect_to @korth
    end

    it "does not redirect if there are no matches" do
      get :index, :q => "Korthsauce"
      response.should_not be_redirect
    end
  end

  describe '#show' do
    it 'goes to the current_user show page' do
      get :show, :id => @user.person.id
      response.should be_success
    end
    describe 'performance' do
      before do
        require 'benchmark'
        @posts = []
        @users = []
        8.times do |n|
          user = Factory.create(:user)
          @users << user
          aspect = user.aspects.create(:name => 'people')
          connect_users(@user, @user.aspects.first, user, aspect)

          @posts << @user.post(:status_message, :message => "hello#{n}", :to => aspect.id)
        end
        @posts.each do |post|
          @users.each do |user|
            user.comment "yo#{post.message}", :on => post
          end
        end
      end

      it 'takes time' do
        Benchmark.realtime{
          get :show, :id => @user.person.id
        }.should < 0.8
      end
    end
    it 'renders with a post' do
      @user.post :status_message, :message => 'test more', :to => @aspect.id
      get :show, :id => @user.person.id
      response.should be_success
    end

    it 'renders with a post' do
      message = @user.post :status_message, :message => 'test more', :to => @aspect.id
      @user.comment 'I mean it', :on => message
      get :show, :id => @user.person.id
      response.should be_success
    end

    it "redirects to #index if the id is invalid" do
      get :show, :id => 'delicious'
      response.should redirect_to people_path
    end

    it "redirects to #index if no person is found" do
      get :show, :id => 3920397846
      response.should redirect_to people_path
    end

    it "renders the show page of a contact" do
      user2 = bob
      get :show, :id => user2.person.id
      response.should be_success
    end

    it 'does not allow xss attacks' do
      user2 = bob
      profile = user2.profile
      profile.first_name = "<script> alert('xss attack');</script>"
      profile.save
      get :show, :id => user2.person.id
      response.should be_success
      response.body.match(profile.first_name).should be_false
    end

    it "renders the show page of a non-contact" do
      user2 = eve
      get :show, :id => user2.person.id
      response.should be_success
    end

    it "renders with public posts of a non-contact" do
      user2 = eve
      status_message = user2.post(:status_message, :message => "hey there", :to => 'all', :public => true)

      get :show, :id => user2.person.id
      assigns[:posts].should include status_message
      response.body.should include status_message.message
    end
  end

  describe '#webfinger' do
    it 'enqueues a webfinger job' do
      Resque.should_receive(:enqueue).with(Job::SocketWebfinger, @user.id, @user.diaspora_handle, anything).once
      get :retrieve_remote, :diaspora_handle => @user.diaspora_handle
    end
  end
end
