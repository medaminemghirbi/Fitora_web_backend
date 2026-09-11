require "prawn"
require "prawn/table"

Prawn::Fonts::AFM.hide_m17n_warning = true

module Payroll
  # Renders the monthly pré-fiche de paie to PDF — one A4 page per employee.
  # `sheet` is the hash from Payroll::MonthlySheet; `employees` an optional
  # subset (defaults to all).
  class SheetPdf
    BRAND = "4F46E5".freeze
    GREY = "64748B".freeze
    LINE = "E2E8F0".freeze

    DAY_FILL = {
      "worked" => "DCFCE7", "leave_paid" => "E0F2FE", "leave_unpaid" => "FEE2E2",
      "off" => "F1F5F9", "na" => "F8FAFC"
    }.freeze

    def self.call(company:, sheet:, employees: nil)
      new(company: company, sheet: sheet, employees: employees).call
    end

    def initialize(company:, sheet:, employees: nil)
      @company = company
      @sheet = sheet
      @employees = employees || sheet[:employees]
    end

    def call
      Prawn::Document.new(page_size: "A4", margin: 40) do |pdf|
        @employees.each_with_index do |emp, i|
          pdf.start_new_page if i.positive?
          render_employee(pdf, emp)
        end
        render_empty(pdf) if @employees.empty?
      end.render
    end

    private

    def render_empty(pdf)
      pdf.text "Aucun employé avec un contrat de travail pour #{@sheet[:month_label]}.", size: 11, color: GREY
    end

    def render_employee(pdf, emp)
      header(pdf)
      pdf.move_down 6
      pdf.text "Pré-fiche de paie — #{@sheet[:month_label]}", size: 15, style: :bold
      pdf.move_down 10

      identity(pdf, emp)
      pdf.move_down 12
      day_grid(pdf, emp)
      pdf.move_down 12
      totals(pdf, emp)
      pdf.move_down 10
      remuneration(pdf, emp)
      footer(pdf)
    end

    def header(pdf)
      pdf.fill_color BRAND
      pdf.text @company.name, size: 16, style: :bold
      pdf.fill_color "000000"
      line = [ @company.address, @company.city, @company.country ].compact_blank.join(", ")
      pdf.text line, size: 8, color: GREY if line.present?
      pdf.stroke_color BRAND
      pdf.move_down 6
      pdf.stroke_horizontal_rule
      pdf.stroke_color "000000"
    end

    def identity(pdf, emp)
      c = emp[:contract]
      rows = [
        [ "Employé", emp[:name] ],
        [ "Poste", emp[:job_title] || role_label(emp[:role]) ],
        [ "Type de contrat", "#{c[:type_name]} (#{c[:type]})" ],
        [ "Référence contrat", c[:reference] || "—" ],
        [ "N° CNSS", c[:cnss_number] || "—" ],
        [ "Période d'emploi", "du #{fmt_date(c[:starts_on])} #{c[:ends_on] ? "au #{fmt_date(c[:ends_on])}" : '(en cours)'}" ]
      ]
      pdf.table(rows, width: pdf.bounds.width) do |t|
        t.cells.borders = [ :bottom ]
        t.cells.border_color = LINE
        t.cells.padding = [ 5, 3 ]
        t.column(0).font_style = :bold
        t.column(0).width = 150
        t.column(0).text_color = GREY
      end
    end

    def day_grid(pdf, emp)
      pdf.text "Jours travaillés & absences", size: 10, style: :bold
      pdf.move_down 4

      blank = { content: "" }
      # Monday-first: pad so the 1st lands under its weekday.
      lead = (emp[:days].first[:date].wday + 6) % 7
      cells = Array.new(lead, blank)
      emp[:days].each do |d|
        label =
          case d[:code]
          when "worked" then "T"
          when "off" then "·"
          when "na" then ""
          else d[:abbr].to_s[0, 3]
          end
        cells << { content: "#{d[:date].day}\n#{label}", background_color: DAY_FILL[d[:code]] }
      end
      cells << blank while cells.size % 7 != 0

      head = %w[Lun Mar Mer Jeu Ven Sam Dim].map { |h| { content: h, font_style: :bold, text_color: GREY } }
      grid = [ head ] + cells.each_slice(7).to_a

      pdf.table(grid, width: pdf.bounds.width, cell_style: { size: 7, align: :center, padding: 3, border_color: LINE }) do |t|
        t.row(0).height = 14
        t.rows(1..-1).height = 26
      end

      pdf.move_down 4
      legend = "T = travaillé   ·   · = repos   " + emp[:absences].map { |a| "#{a[:abbreviation]} = #{a[:absence_type]}" }.join("   ")
      pdf.text legend, size: 7, color: GREY
    end

    def totals(pdf, emp)
      rows = [
        [ "Jours ouvrés du mois", @sheet[:working_days].to_s ],
        [ "Jours ouvrés couverts par le contrat", emp[:working_days].to_s ],
        [ "Jours travaillés", emp[:worked_days].to_s ],
        [ "Jours d'absence (payés)", emp[:paid_absence_days].to_s ],
        [ "Jours d'absence (non payés)", emp[:unpaid_absence_days].to_s ]
      ]
      emp[:absences].each { |a| rows << [ "  dont #{a[:absence_type]} (#{a[:abbreviation]})", a[:days].to_s ] }

      pdf.table(rows, width: pdf.bounds.width) do |t|
        t.cells.borders = [ :bottom ]
        t.cells.border_color = LINE
        t.cells.padding = [ 5, 3 ]
        t.column(0).text_color = GREY
        t.column(1).align = :right
        t.column(1).font_style = :bold
      end
    end

    def remuneration(pdf, emp)
      cur = emp[:currency]
      rows = [ [ "Salaire de base", money(emp[:gross_monthly_salary], cur) ] ]
      Array(emp[:allowances]).each { |a| rows << [ a["label"], "+ #{money(a['amount'], cur)}" ] }
      rows << [ "Brut mensuel de référence", money(emp[:total_monthly_gross], cur) ]
      rows << [ "Brut estimé du mois (au prorata des absences non payées)", money(emp[:estimated_gross], cur) ]

      pdf.table(rows, width: pdf.bounds.width) do |t|
        t.cells.borders = [ :bottom ]
        t.cells.border_color = LINE
        t.cells.padding = [ 6, 4 ]
        t.column(1).align = :right
        t.row(rows.size - 2).font_style = :bold
        t.row(rows.size - 1).font_style = :bold
        t.row(rows.size - 1).text_color = BRAND
      end

      pdf.move_down 6
      pdf.text "Document préparatoire. Les cotisations CNSS, l'IRPP et le net à payer sont calculés par le service comptable.",
               size: 7, color: GREY, style: :italic
    end

    def footer(pdf)
      pdf.move_down 16
      pdf.text "Généré le #{Time.current.strftime('%d/%m/%Y %H:%M')}", size: 7, color: GREY
    end

    def role_label(role)
      { "manager" => "Manager", "receptionist" => "Réceptionniste", "coach" => "Coach" }.fetch(role, role)
    end

    def fmt_date(date)
      date.respond_to?(:strftime) ? date.strftime("%d/%m/%Y") : date.to_s
    end

    def money(amount, currency)
      value = amount.to_f
      formatted = value == value.round ? value.round.to_s : format("%.3f", value).sub(/0+$/, "").sub(/\.$/, "")
      "#{formatted} #{currency}"
    end
  end
end
