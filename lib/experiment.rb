require 'nokogiri'

class SRAExperimentXML < Nokogiri::XML::SAX::Document
  def initialize
    write_prefixes

    @parent_name = []
    @inner_text = ""

    @experiment_attr = {
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
      @experiment_attr[:design][:library_layout][:type] = name
      @experiment_attr[:design][:library_layout][:nominal_length] = h["NOMINAL_LENGTH"]
      @experiment_attr[:design][:library_layout][:nominal_sdev] = h["NOMINAL_SDEV"]
    when "PLATFORM"
      @experiment_attr[:platform] = name
    end
    @parent_name << name

    case name
    when "EXPERIMENT"
      @experiment_attr[:id] = attrs.to_h["accession"]
    end
  end

  def characters(string)
    @inner_text = string
  end

  def end_element(name)
    case name
    when "TITLE"
      @experiment_attr[:title] = @inner_text
    when "DESIGN_DESCRIPTION"
      @experiment_attr[:design_description] = @inner_text
    when "LIBRARY_NAME"
      @experiment_attr[:design][:library_name] = @inner_text
    when "LIBRARY_STRATEGY"
      @experiment_attr[:design][:library_strategy] = @inner_text
    when "LIBRARY_SOURCE"
      @experiment_attr[:design][:library_source] = @inner_text
    when "LIBRARY_SELECTION"
      @experiment_attr[:design][:library_selection] = @inner_text
    when "LIBRARY_CONSTRUCTION_PROTOCOL"
      @experiment_attr[:design][:library_construction_protocol] = @inner_text
    when "INSTRUMENT_MODEL"
      @experiment_attr[:instrument_model] = @inner_text
    when "EXPERIMENT"
      output_turtle
    end
  end

  #
  # functions
  #

  def write_prefixes
    puts "@base <http://bio.cow/ontology/sra-experiement/> ."
    puts "@prefix id: <http://identifiers.org/insdc.sra/> ."
    puts "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ."
    puts "@prefix dct: <http://purl.obolibrary.org/obo/> ."
    puts ""
  end

  def output_turtle
    p @experiment_attr
  end

  # def attribute(attrs)
  #   h = attrs.to_h
  #   @sample_properties[:additional_properties] << {
  #     attribute_name: h["attribute_name"],
  #     harmonized_name: h["harmonized_name"],
  #     display_name: h["display_name"],
  #   }
  # end
  #
  # def attribute_value
  #   h = @sample_properties[:additional_properties].pop
  #   h[:property_value] = @inner_text
  #   @sample_properties[:additional_properties] << h
  # end
  #
  # def output_turtle
  #   puts "bs:#{@sample_properties[:id]} a <DataRecord>;"
  #   puts "  <dateCreated> \"#{@sample_properties[:submission_date]}\"^^<Date>;"
  #   puts "  <dateModified> \"#{@sample_properties[:last_update]}\"^^<Date>;"
  #   puts "  <identifier> \"biosample:#{@sample_properties[:id]}\";"
  #   puts "  <isPartOf> <https://www.ebi.ac.uk/biosamples/samples>;"
  #   puts "  <mainEntity> ["
  #   puts "    a <Sample>, obo:OBI_0000747;"
  #   puts "    <name> \"#{@sample_properties[:id]}\";"
  #   puts "    <identifier> \"biosample:#{@sample_properties[:id]}\";"
  #   puts "    dct:identifier \"#{@sample_properties[:id]}\";"
  #   puts "    <subjectOf> \"https://www.ebi.ac.uk/ena/data/view/#{@sample_properties[:id]}\";"
  #   puts "    <description> \"#{@sample_properties[:description_title]}\";"
  #
  #   puts "    <additionalProperty> ["
  #   n = @sample_properties[:additional_properties].size
  #   @sample_properties[:additional_properties].each_with_index do |p,i|
  #     puts "      a <PropertyValue>;"
  #     puts "      <name> \"#{p[:harmonized_name] ? p[:harmonized_name] : p[:attribute_name]}\";"
  #     puts "      <value> \"#{p[:property_value]}\""
  #     if i != n-1
  #       puts "    ], ["
  #     end
  #   end
  #   puts "    ] ."
  # end
end
