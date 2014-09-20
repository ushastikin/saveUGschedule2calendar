# encoding: utf-8     # for writing hebrew letters?

require 'nokogiri'
require 'open-uri'
#require 'iconv'

class StaticPagesController < ApplicationController
  def home
    @link = params[:link]
    @csv_content = get_csv(@link)
  end

  def save_csv
    @csv_content = params[:csv_content]
    if !@csv_content.nil? && !@csv_content.empty?
      #csv_content_windows1255 = Iconv.conv('windows-1255', 'utf-8', @csv_content)
      #send_data csv_content_windows1255,
      send_data @csv_content,
                :filename => 'schedule.csv',
                :type => 'text/csv'
      #:type => 'text/csv; charset=windows-1255'
    else
      render :home
    end
  end

  private
  def get_csv(link)
    return 'Please, enter some link above' if link.nil? || link.empty?
    # csv format
    #Subject,Start Date,Start Time,End Date,End Time,Location
    csv_exams = 'Subject,Start Date,Start Time,End Date,End Time,Location'

    begin
      # new page example
      #link = 'http://ug3.technion.ac.il/rishum/weekplan.php?RGS=234247212363431123635311&SEM=201302'
      doc = Nokogiri::HTML(open(link), nil, 'utf-8')
    rescue
      return 'Please, check that your link is valid'
    end

    tables = doc.search('table')
    exams_table = tables.last

    exams_table.search('tr')[2..-1].each do |row|
      row_columns = row.search('td')

      # get exams subject
      subject = row_columns[1].content
      subject_a = "#{subject} מועד א"
      subject_b = "#{subject} מועד ב"
      # get exams dates
      date_exam_a = row_columns[-2].content
      date_exam_b = row_columns[-1].content
      # get exams time and location
      course_number = row_columns[0].content.split('-')[0]
      semester_code = link.split('/')[-1].split('=')[-1]
      link_to_exam_details = "http://ug3.technion.ac.il/rishum/exams/#{course_number}/#{semester_code}"
      exam_doc = Nokogiri::HTML(open(link_to_exam_details), nil, 'utf-8')
      time = exam_doc.xpath('//div[@class="property-value"]')[1].content
      start_time_a = time.split('-')[0]
      end_time_a = time.split('-')[1]
      time = exam_doc.xpath('//div[@class="property-value"]')[5].content
      start_time_b = time.split('-')[0]
      end_time_b = time.split('-')[1]
      location_a = exam_doc.css('div.property-value')[3].inner_html.gsub!(/<br>/, ' ')
      location_b = exam_doc.css('div.property-value')[7].inner_html.gsub!(/<br>/, ' ')

      csv_exams << "\n#{subject_a},#{date_exam_a},#{start_time_a}:00,#{date_exam_a},#{end_time_a}:00,#{location_a}" unless date_exam_a.empty?
      csv_exams << "\n#{subject_b},#{date_exam_b},#{start_time_b}:00,#{date_exam_b},#{end_time_b}:00,#{location_b}" unless date_exam_b.empty?
    end

    csv_exams
    #puts csv_exams
    #file = File.new("exams.csv", "w:utf-8")
    #file.puts csv_exams
    #file.close
  end
end
