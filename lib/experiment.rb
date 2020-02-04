require 'nokogiri'

class SRAExperimentXML < Nokogiri::XML::SAX::Document
  def initialize
    write_prefixes

    @parent_name = []
    @inner_text = ""

    @exp = {
      id: "",
      platform: "",
      instrument_model: "",
      design_description: "",
      title: "",
      design: {
        library_selection: "",
        library_source: "",
        library_layout: {
          type: "",
          nominal_length: "",
          nominal_sdev: "",
        },
        library_construction_protocol: "",
        library_strategy: "",
        library_name: "",
      }
    }
  end

  #
  # SAX Event triggers
  #

  def start_element(name, attrs = [])
    case @parent_name.last
    when "LIBRARY_LAYOUT"
      h = attrs.to_h
      @exp[:design][:library_layout][:type] = name.gsub("\s","_")
      @exp[:design][:library_layout][:nominal_length] = h["NOMINAL_LENGTH"]
      @exp[:design][:library_layout][:nominal_sdev] = h["NOMINAL_SDEV"]
    when "PLATFORM"
      @exp[:platform] = name.gsub("\s","_")
    end
    @parent_name << name

    case name
    when "EXPERIMENT"
      @exp[:id] = attrs.to_h["accession"]
    end
  end

  def characters(string)
    @inner_text = string.gsub(/\s+$/,"").chomp
  end

  def end_element(name)
    case name
    when "TITLE"
      @exp[:title] = @inner_text
    when "DESIGN_DESCRIPTION"
      @exp[:design_description] = @inner_text
    when "LIBRARY_NAME"
      @exp[:design][:library_name] = @inner_text
    when "LIBRARY_STRATEGY"
      @exp[:design][:library_strategy] = @inner_text.gsub("\s","_")
    when "LIBRARY_SOURCE"
      @exp[:design][:library_source] = @inner_text.gsub("\s","_")
    when "LIBRARY_SELECTION"
      @exp[:design][:library_selection] = @inner_text.gsub("\s","_")
    when "LIBRARY_CONSTRUCTION_PROTOCOL"
      @exp[:design][:library_construction_protocol] = @inner_text
    when "INSTRUMENT_MODEL"
      @exp[:instrument_model] = @inner_text.gsub("\s","_")
    when "EXPERIMENT"
      output_turtle
    end
  end

  #
  # functions
  #

  def write_prefixes
    puts "@prefix : <http://bio.cow/ontology/sra-experiement/> ."
    puts "@prefix id: <http://identifiers.org/insdc.sra/> ."
    puts "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ."
    puts "@prefix dct: <http://purl.obolibrary.org/obo/> ."
    puts ""
  end

  def output_turtle
    puts "id:#{@exp[:id]} a :Experiment ;"
    puts "  rdfs:label \"#{@exp[:id]}: #{@exp[:title]}\" ;"
    puts "  dct:identifier \"#{@exp[:id]}\" ;"
    puts "  :designDesctiption \"#{@exp[:design_description]}\" ;"
    puts "  dct:description \"#{@exp[:design_description]}\" ;"
    puts "  :title \"#{@exp[:title]}\" ;"
    puts "  :platform ["
    puts "    a :#{@exp[:platform]} ;"
    puts "    :instrumentModel :#{@exp[:instrument_model]}"
    puts "  ] ;"
    puts "  :design ["
    puts "    a :ExperimentDesign ;"
    puts "    :libraryName \"#{@exp[:design][:library_name]}\" ;"
    puts "    :libraryStrategy :#{@exp[:design][:library_strategy]} ;"
    puts "    :librarySource :#{@exp[:design][:library_source]} ;"
    puts "    :librarySelection :#{@exp[:design][:library_selection]} ;"
    puts "    :libraryConstructionProtocol \"#{@exp[:design][:library_construction_protocol]}\" ;"
    puts "    :libraryLayout ["
    puts "      a :#{@exp[:design][:library_layout][:type]} ;"
    puts "      :nominalLength \"#{@exp[:design][:library_layout][:nominal_length]}\" ;"
    puts "      :nominalSdev \"#{@exp[:design][:library_layout][:nominal_sdev]}\""
    puts "    ]"
    puts "  ] ."
  end
end
