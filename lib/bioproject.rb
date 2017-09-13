require 'open-uri'
require 'json'
# require 'json/ld'
# require 'rdf/turtle'

class PunkAPI
  class << self
    attr_accessor :endpoint_url
  end

  class BioProject
    @@rdf_version = "0.1.0"

    def initialize(id)
      @id = id
      @url = "http://#{PunkAPI.endpoint_url}/bioproject/#{@id}"
      @data = JSON.load(open(@url).read)
      @graph = jsonld_core
    end

    def to_json
      @data
    end

    def to_json_ld
      jsonld_core
    end

    def jsonld_entry_type
      "biocow:BioProject"
    end

    def jsonld_core
      pm          = predicate_mappings
      submission  = bioproject_submission
      description = bioproject_project_description
      id          = bioproject_project_id
      type        = bioproject_project_type

      {
        "@context" => jsonld_context,
        "@id" => "http://identifiers.org/bioproject/" + @id,
        "@type" => jsonld_entry_type,

        # General metadata
        "rdfs:label" => description[:name],
        "dcterms:identifier" => @id,

        # Project/Submission
        pm[:date_submitted] => submission[:date_submitted],
        pm[:date_last_updated] => submission[:date_last_updated],
        pm[:data_access] => submission[:data_access],
        pm[:organization] => {
          pm[:organization_name] => submission[:organization_name],
          pm[:organization_role] => submission[:organization_role],
          pm[:organization_type] => submission[:organization_type],
        },

        # Project/Project/Description
        pm[:name] => description[:name],
        pm[:release_date] => description[:release_date],
        pm[:relevance] => {
          pm[:hasPropertyType] => {
            "rdfs:label" => description[:relevance].keys.first,
          },
          pm[:hasPropertyValue] => {
            "rdfs:label" => description[:relevance].values.first,
          },
        },
        pm[:title] => description[:title],
        pm[:description] => description[:description],

        # Project/Project/ID
        pm[:archive] => id[:archive],
        pm[:archive_id] => id[:archive_id],
        pm[:archive_accession_id] => id[:archive_accession_id],

        # Project/Project/Type
        pm[:method] => {
          "rdfs:label" => type[:method_type],
        },
        pm[:data] => {
          "rdfs:label" => type[:data_type],
        },
        pm[:objectives] => type[:objectives].map{|obj| { "rdfs:label" => obj } }, # Array of hashes which only has label
        pm[:target] => {
          pm[:material] => type[:target_material],
          pm[:sample_scope] => type[:target_sample_scope],
          pm[:capture] => type[:target_capture],
          pm[:organism] => {
            "@type" => "ddbj-tax:Taxon",
            "@id" => "http://identifiers.org/taxonomy/" + type[:target_organism_taxid],
            "dcterms:identifier" => type[:target_organism_taxid],
            pm[:supergroup] => type[:target_organism_supergroup],
            pm[:species] => type[:target_organism_species],
            pm[:organism_name] => type[:target_organism_name],
            "rdfs:label" => type[:target_organism_name],
          },
        },
        pm[:objectives] => type[:objectives],
      }
    end

    def predicate_mappings
      {
        # Project/Submission
        :date_submitted => "dcterms:dateSubmitted",
        :date_last_updated => "dcterms:modified",
        :data_access => "biocow:status",
        :organization => "dcterms:contributor",
        :organization_name => "foaf:name",
        :organization_role => "sio:hasRole",
        :organization_type => "rdfs:type",
        # Project/Project/Description
        :name => "foaf:name",
        :relevance => "biocow:relevantTo",
        :hasPropertyType => "biocow:hasPropertyType",
        :hasPropertyValue => "biocow:hasPropertyValue",
        :release_date => "dcterms:available",
        :title => "dcterms:title",
        :description => "dcterms:description",
        # Project/Project/ID
        :archive => "biocow:hostedBy",
        :archive_id => "biocow:has_archive_id",                  # may require to create our own term
        :archive_accession_id => "biocow:has_archive_accession", # may require to create our own term
        # Project/Project/Type
        :method => "biocow:hasMethod",
        :data => "biocow:hasData",
        :objectives => "biocow:hasObjective",
        # Project/Project/Type/Target
        :target => "sio:hasTarget",
        :material => "biocow:hasMaterial",
        # Project/Project/Type/Target/Organism
        :organism => "biocow:hasOrganism",
        :supergroup => "biocow:supergroup",
        :species => "biocow:species",
        :organism_name => "ddbj-tax:scientificName",
      }
    end

    def bioproject_submission
      submission = @data["Package"]["Project"]["Submission"]
      {
        :date_submitted => submission["@submitted"],
        :date_last_updated => submission["@last_updated"],
        :data_access => submission["Description"]["Access"],
        :organization_name => submission["Description"]["Organization"]["Name"],
        :organization_role => submission["Description"]["Organization"]["@role"],
        :organization_type => submission["Description"]["Organization"]["@type"],
      }
    end

    def bioproject_project
      {
        :project_description => bioproject_project_description,
        :project_id => bioproject_project_id,
        :project_type => bioproject_project_type,
      }
    end

    def bioproject_project_description
      project_desc = @data["Package"]["Project"]["Project"]["ProjectDescr"]
      {
        :name => project_desc["Name"],
        :release_date => project_desc["ProjectReleaseDate"],
        :relevance => project_desc["Relevance"],              # Key-Value Hash
        :title => project_desc["Title"],
        :description => project_desc["Description"],
      }
    end

    def bioproject_project_id
      project_id = @data["Package"]["Project"]["Project"]["ProjectID"]
      {
        :archive => project_id["ArchiveID"]["@archive"],
        :archive_id => project_id["ArchiveID"]["@id"],
        :archive_accession_id => project_id["ArchiveID"]["@accession"],
      }
    end

    def bioproject_project_type
      project_type = @data["Package"]["Project"]["Project"]["ProjectType"]
      project_type_submission = project_type["ProjectTypeSubmission"]
      project_type_method = project_type_submission["Method"]
      project_type_data_type_set = project_type_submission["ProjectDataTypeSet"]
      project_target = project_type_submission["Target"]
      project_objective = project_type_submission["Objectives"]
      {
        :method_type => project_type_method["@method_type"],
        :data_type => project_type_data_type_set["DataType"],
        :target_material => project_target["@material"],
        :target_sample_scope => project_target["@sample_scope"],
        :target_capture => project_target["@capture"],
        :target_organism_supergroup => project_target["Organism"]["Supergroup"],
        :target_organism_taxid => project_target["Organism"]["@taxID"],
        :target_organism_species => project_target["Organism"]["@species"],
        :target_organism_name => project_target["Organism"]["OrganismName"],
        :objectives => project_objective["Data"].map{|n| n["@data_type"] },    # Array of data type
      }
    end

    def jsonld_context
      {
        "rdfs" => "http://www.w3.org/2000/01/rdf-schema#",
        "dcterms" => "http://purl.org/dc/terms/",
        "pav" => "http://purl.org/pav/",
        "foaf" => "http://xmlns.com/foaf/0.1/",
        "sio" => "http://semanticscience.org/resource/",
        # "obo" => "http://purl.obolibrary.org/obo/",
        # "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        # "xsd" => "http://www.w3.org/2001/XMLSchema#",
      }
    end
  end
end

if __FILE__ == $0
  endpoint_url = "52.199.195.71"
  PunkAPI.endpoint_url = endpoint_url

  id = "PRJDB4503"
  bp = PunkAPI::BioProject.new(id)

  #puts JSON.pretty_generate(bp.to_json)
  puts JSON.pretty_generate(bp.to_json_ld)
end
