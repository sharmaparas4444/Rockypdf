#***** BEGIN LICENSE BLOCK *****
#
#Version: RTV Public License 1.0
#
#The contents of this file are subject to the RTV Public License Version 1.0 (the
#"License"); you may not use this file except in compliance with the License. You
#may obtain a copy of the License at: http://www.osdv.org/license12b/
#
#Software distributed under the License is distributed on an "AS IS" basis,
#WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the
#specific language governing rights and limitations under the License.
#
#The Original Code is the Online Voter Registration Assistant and Partner Portal.
#
#The Initial Developer of the Original Code is Rock The Vote. Portions created by
#RockTheVote are Copyright (C) RockTheVote. All Rights Reserved. The Original
#Code contains portions Copyright [2008] Open Source Digital Voting Foundation,
#and such portions are licensed to you under this license by Rock the Vote under
#permission of Open Source Digital Voting Foundation.  All Rights Reserved.
#
#Contributor(s): Open Source Digital Voting Foundation, RockTheVote,
#                Pivotal Labs, Oregon State University Open Source Lab.
#
#***** END LICENSE BLOCK *****
require File.expand_path(File.dirname(__FILE__) + '/../rails_helper')

describe DownloadsController do
  render_views

  
  describe 'show' do
    before(:each) do
      Partner.any_instance.stub(:valid_api_key?).and_return(true)
    end

    describe "when PDF is ready" do
      before(:each) do
        @registrant = FactoryGirl.create(:maximal_registrant)
        Registrant.any_instance.stub(:pdf_ready?).and_return(true)
      end

      it "provides a link to download the PDF" do
        get :show, :registrant_id => @registrant.to_param
        assert !assigns[:registrant].nil?
        assert_response :success
        assert_template "show"
        assert_select "span.button a[target=_blank]"
      end

    end

    describe "when PDF is not ready" do
      before(:each) do
        @registrant = FactoryGirl.create(:step_5_registrant)
        Registrant.any_instance.stub(:pdf_ready?).and_return(false)
      
      end
      context 'with javascript enabled' do
        context 'when email address is present' do
          it "renders a preparing page that polls the PDF ready api with the registrant UID and a timeout redirect" do
            get :show, :registrant_id => @registrant.to_param
            assert !assigns[:registrant].nil?
            assert assigns[:timeout] == true
            assert_response :success
            assert_template "preparing"
          end        
        end
        context 'with no email address' do
          it "renders a preparing page that polls the PDF ready api with the registrant UID with no timeout" do
            @registrant.collect_email_address = 'no'
            @registrant.email_address = ''
            @registrant.save!
            get :show, :registrant_id => @registrant.to_param
            assert !assigns[:registrant].nil?
            assert assigns[:timeout] == false
            assert_response :success
            assert_template "preparing"
          end                
        end
      end
      context 'when javascript is disabled' do
        before(:each) do
          @registrant.javascript_disabled = true
          @registrant.save!
        end
        it "provides a link to download the PDF" do
          get :show, :registrant_id => @registrant.to_param
          assert !assigns[:registrant].nil?
          assert_response :success
          assert_template "preparing"
        end
        context 'when the user has an email address' do
          it "times out preparing page after 30 seconds" do
            Registrant.where("id = #{@registrant.id}").update_all("updated_at = '#{35.seconds.ago.to_s(:db)}'")
            get :show, :registrant_id => @registrant.to_param
            assert !assigns[:registrant].nil?
            assert_redirected_to registrant_finish_url(@registrant)
          end
        end
        context 'when the user has no email' do
          before(:each) do
            @registrant.collect_email_address = 'no'
            @registrant.email_address = nil
            @registrant.save!
          end
          it "does not times out preparing page after 30 seconds" do
            Registrant.where("id = #{@registrant.id}").update_all("updated_at = '#{125.seconds.ago.to_s(:db)}'")
            get :show, :registrant_id => @registrant.to_param
            assert !assigns[:registrant].nil?
            assert_response :success
            assert_template "preparing"
          end
        end
      end

    end
  end

  describe 'download' do
    let(:registrant) { FactoryGirl.create(:maximal_registrant) }
    before(:each) do
      Partner.any_instance.stub(:valid_api_key?).and_return(true)
    end

    describe "when PDF is not ready" do
      before(:each) do
        registrant.update_attributes(pdf_ready: false)
      end    
      it 'redirects to finish page w/not ready' do
        get :pdf, registrant_id: registrant.to_param
        #/registrants/"+uid+"/finish?not_ready=true
        assert_redirected_to registrant_finish_path(registrant, not_ready: true)
      end  
      it "does not set pdf_downloaded" do
        get :pdf, registrant_id: registrant.to_param
        
        registrant.reload
        registrant.pdf_downloaded.should == false
        registrant.pdf_downloaded_at.should be_nil
      end
          
    end
    
    describe 'when PDF is ready' do
      before(:each) do
        registrant.update_attributes(pdf_ready: true)
      end 
      it 'sets pdf_downloaded' do        
        get :pdf, registrant_id: registrant.to_param
        registrant.reload
        registrant.pdf_downloaded.should == true
        registrant.pdf_downloaded_at.should_not be_nil
      end
      it 'redirects to pdf file' do
        get :pdf, registrant_id: registrant.to_param
        assert_redirected_to registrant.pdf_url
      end
    end
    
  end
end
