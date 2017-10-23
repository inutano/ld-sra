require 'open-uri'
require 'json'
require 'json/ld'
require 'rdf/turtle'

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
      @graph = jsonld
    end

    def json
      @data
    end

    def turtle
      turtle_graph.dump(:ttl, prefixes: turtle_context)
    end

    def turtle_graph
      RDF::Graph.new << JSON::LD::API.toRdf(jsonld)
    end

    def jsonld_entry_type
      "biocow:BioProject"
    end

    def context
      turtle_context.merge(jsonld_context)
    end

    def turtle_context
      {
        # "obo" => "http://purl.obolibrary.org/obo/",
        # "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "bao" => "http://www.bioassayontology.org/bao#",
        "biocow" => "http://bio.cow/",
        "dcterms" => "http://purl.org/dc/terms/",
        "ddbj-tax" => "http://ddbj.nig.ac.jp/ontologies/taxonomy/",
        "foaf" => "http://xmlns.com/foaf/0.1/",
        "pav" => "http://purl.org/pav/",
        "rdfs" => "http://www.w3.org/2000/01/rdf-schema#",
        "schema" => "http://schema.org/",
        "sio" => "http://semanticscience.org/resource/",
        "xsd" => "http://www.w3.org/2001/XMLSchema#",
      }
    end

    def jsonld_context
      {
        "URI" => "@id",
        "entry_type" => "@type",
        "label" => "rdfs:label",
        # Project/Submission
        "Submission" => "@nest",
        "date_submitted" => {
          "@id" => "dcterms:dateSubmitted",
          "@type" => "xsd:dateTime",
        },
        "date_last_update" => {
          "@id" => "dcterms:modified",
          "@type" => "xsd:dateTime",
        },
        "access" => "dcterms:accessRights", # Need a fix since dcterms:accessRight is ObjectProperty
        "organization" => "pav:authoredBy",
        "organization_name" => "foaf:name",
        "organization_role" => "sio:SIO_000228", # has role, need a fix since sio:hasRole is ObjectProperty
        "organization_type" => "biocow:organization_type",
        # Project/Project/Description
        "Project" => "@nest",
        "ProjectDescription" => "@nest",
        "name" => "rdfs:label",
        "relevance" => "sio:SIO000668", # in relation to
        "propertyType" => "biocow:hasPropertyType",
        "propertyValue" => "biocow:hasPropertyValue",
        "release_date" => {
          "@id" => "dcterms:available",
          "@type" => "xsd:dateTime",
        },
        "title" => "dcterms:title",
        "description" => "dcterms:description",
        # Project/Project/ID
        "ProjectID" => "@nest",
        "ArchiveID" => {
          "@id" => "@nest",
          "@context" => {
            "archive" => "pav:providedBy",
            "id" => "biocow:archive_id",
            "accession" => "dcterms:identifier",
          },
        },
        # Project/Project/Type
        "ProjectType" => "@nest",
        "method_type" => "bao:BAO_0000212", # has assay method
        "data_type" => "biocow:data_type",
        "objectives" => "sio:SIO_000362", # satisfies
        # Project/Project/Type/Target
        "target" => "sio:SIO_000291", # has target
        "material" => "sio:SIO_000132", # has participant
        # Project/Project/Type/Target/Organism
        "organism" => {
          "@id" => "bao:BAO_0002921", # has organism
          "@type" => "ddbj-tax:Taxon",
        },
        "taxid" => "dcterms:identifier",
        "supergroup" => "biocow:supergroup",
        "species" => "biocow:species",
        "organism_name" => "ddbj-tax:scientificName",
      }
    end

    def jsonld
      submission  = bioproject_submission
      description = bioproject_project_description
      id          = bioproject_project_id
      type        = bioproject_project_type

      {
        "@context" => context,
        "URI" => "http://identifiers.org/bioproject/" + @id,
        "entry" => jsonld_entry_type,

        # Project/Submission
        "Submission" => {
          "date_submitted" => submission[:date_submitted],
          "date_last_update" => submission[:date_last_update],
          "access" => submission[:access],
          "organization" => {
            "organization_name" => submission[:organization_name],
            "organization_role" => submission[:organization_role],
            "organization_type" => submission[:organization_type],
          },
        },
        "Project" => {
          "ProjectDescription" => {
            "name" => description[:name],
            "release_date" => description[:release_date],
            "relevance" => {
              "propertyType" => {
                "label" => description[:relevance].keys.first,
              },
              "propertyValue" => {
                "label" => description[:relevance].values.first,
              },
            },
            "title" => description[:title],
            "description" => description[:description],
          },
          "ProjectID" => {
            "ArchiveID" => {
              "archive" => id[:archive],
              "id" => id[:archive_id],
              "accession" => id[:archive_accession_id],
            },
          },
          "ProjectType" => {
            "data_type" => type[:data_type],
            "method_type" => type[:method_type],

            "objectives" => type[:objectives], #.map{|obj| { "label" => obj } }, # Array of hashes which only has label
            "target" => {
              "material" => type[:target_material],
              "sample_scope" => type[:target_sample_scope],
              "capture" => type[:target_capture],
              "organism" => {
                "label" => type[:target_organism_name],
                "seeAlso" => "http://identifiers.org/taxonomy/" + type[:target_organism_taxid],

                "taxid" => type[:target_organism_taxid],
                "supergroup" => type[:target_organism_supergroup],
                "species" => type[:target_organism_species],
                "organism_name" => type[:target_organism_name],
              },
            },
          },
        },
      }
    end

    def bioproject_submission
      submission = @data["Package"]["Project"]["Submission"]
      {
        :date_submitted => submission["@submitted"],
        :date_last_update => submission["@last_update"],
        :access => submission["Description"]["Access"],
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
  end
end

if __FILE__ == $0
  endpoint_url = "52.199.195.71"
  PunkAPI.endpoint_url = endpoint_url

  ids = ["PRJDB4503","PRJNA215990","PRJEB6637","PRJNA260331",]

  ids.each do |id|
    bp = PunkAPI::BioProject.new(id)
    case ARGV.first
    when "turtle"
      puts bp.turtle
    when "json"
      puts JSON.pretty_generate(bp.json)
    when "jsonld"
      puts JSON.pretty_generate(bp.jsonld)
    end
  end
end
