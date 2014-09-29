# encoding: utf-8     # for writing hebrew letters?

require 'nokogiri'
require 'open-uri'
#require 'iconv'

class StaticPagesController < ApplicationController
  # main method used almost for everything, since it is one page service
  def home
    @link = params[:link]

    # define content type in the session cache for CSV file name
    Rails.cache.write('csv_content_type', 'empty')

    unless @link.nil? || @link.empty?
      link_regexp = /https?:\/\/ug3\.technion\.ac\.il\/rishum\/weekplan\.php\?RGS=([0-9]{8})*&SEM=[0-9]{6}/
      if @link =~ link_regexp
        # parse link to get courses/groups numbers and semester number
        tmp = @link.split('RGS=')[-1]
        courses_string = tmp.split('&SEM=')[0]
        course_group = {}
        courses_string.chars.each_slice(8) do |course_string|
          course_group[course_string[0..5].join] = course_string[6,7].join
        end
        semester_code = tmp.split('&SEM=')[-1]

        # csv format
        #Subject,Start Date,Start Time,End Date,End Time,Location
        csv_exams = 'Subject,Start Date,Start Time,End Date,End Time,Location'

        if params[:commit] == 'Generate file content for exams'
          @csv_content = get_exams_csv(@link, semester_code, csv_exams)
          Rails.cache.write('csv_content_type', 'ug_exams_calendar')
        else
          raise unless params[:commit] == 'Generate file content for schedule'
          @csv_content = get_schedule_csv(course_group, semester_code, csv_exams)
          Rails.cache.write('csv_content_type', 'ug_schedule_calendar')
        end
      else
        @csv_content = 'Please, check that your link is valid'
      end
    end
  end

  # method saving generated CSV content to the file
  def save_csv
    @csv_content = params[:csv_content]
    if !@csv_content.nil? && !@csv_content.empty?
      #csv_content_windows1255 = Iconv.conv('windows-1255', 'utf-8', @csv_content)
      #send_data csv_content_windows1255,
      send_data @csv_content,
                :filename => "#{Rails.cache.read('csv_content_type')}.csv",
                :type => 'text/csv'
      #:type => 'text/csv; charset=windows-1255'
    else
      render :home
    end
  end

  private

  def get_schedule_csv(course_group, semester_code, csv_exams)
    course_group.each_pair do |course_number, course_group_number|
      link_to_course_details = "http://ug3.technion.ac.il/rishum/course/#{course_number}/#{semester_code}"
      schedule_doc = Nokogiri::HTML(open(link_to_course_details), nil, 'utf-8')
      # get data for each course
      schedule_doc.xpath('//table[@class="rishum-groups"]/tr').each do |line|
        course_name = schedule_doc.xpath('//div[@class="property-value"]')[0].content.strip
        if line.search('td')[0].content == course_group_number
          lesson_types = line.search('td')[3].inner_html.split('<br>')
          week_days = line.search('td')[5].inner_html.split('<br>')
          times = line.search('td')[6].inner_html.split('<br>')
          buildings = line.search('td')[7].inner_html.split('<br>')
          rooms = line.search('td')[8].inner_html.split('<br>')
          # TODO: replace by some generic method according to http://www.admin.technion.ac.il/dpcalendar/
          semester_start_dates = {
              201302 => '2014-10-06', # for test
              201303 => '2014-08-14',
              201401 => '2014-10-20',
              201402 => '2015-03-17',
          }
          semester_end_dates = {
              201302 => '2014-10-15', # for test
              201303 => '2014-09-14',
              201401 => '2015-01-22',
              201402 => '2015-06-28',
          }
          semester_start_date = Date.parse(semester_start_dates[semester_code.to_i])
          semester_end_date = Date.parse(semester_end_dates[semester_code.to_i])
          semester_start_date_sunday = semester_start_date - semester_start_date.wday.day
          # go through all weeks of the semester and save lessons data
          semester_start_date_sunday.step(semester_end_date, 7).each do |date_week_start|
            lesson_types.each_with_index do |lesson_type, index|
              start_time = times[index].split('-')[0].strip
              end_time = times[index].split('-')[1].strip
              location = "#{buildings[index]} #{rooms[index]}"
              # add converted hebrew week day to start week date
              date = date_week_start + (week_days[index][0].ord - 'א'[0].ord).day
              if semester_start_date <= date && date <= semester_end_date
                csv_exams << "\n#{course_name} #{lesson_type},#{date},#{start_time}0,#{date},#{end_time}0,#{location}"
              end
            end
          end
        end
      end
    end

    csv_exams
  end

  def get_exams_csv(link, semester_code, csv_exams)
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
      # semester_code = link.split('/')[-1].split('=')[-1]
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
    # for debug
    #puts csv_exams
    #file = File.new("exams.csv", "w:utf-8")
    #file.puts csv_exams
    #file.close
  end
end
