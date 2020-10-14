import xml.etree.ElementTree as ET
import sys
import re
import argparse


def output_turtle(exp):
    print("id:" + exp["id"] + " a :Experiment ;\n" +
          "  rdfs:label \"" + exp["id"] + ": " + exp["title"] + "\" ;\n" +
          "  dct:identifier \"" + exp["id"] + "\" ;\n" +
          "  :designDesctiption \"" + exp["design_description"] + "\" ;\n" +
          "  dct:description \"" + exp["design_description"] + "\" ;\n" +
          "  :title \"" + exp["title"] + "\" ;\n" +
          "  :platform [\n" +
          "    a :" + exp["platform"] + " ;\n" +
          "    :instrumentModel :" + exp["instrument_model"] + "\n" +
          "  ] ;\n" +
          "  :design [\n" +
          "    a :ExperimentDesign ;\n" +
          "    :libraryName \"" + exp["design"]["library_name"] + "\" ;\n" +
          "    :libraryStrategy :" + exp["design"]["library_strategy"] + " ;\n" +
          "    :librarySource :" + exp["design"]["library_source"] + " ;\n" +
          "    :librarySelection :" + exp["design"]["library_selection"] + " ;\n" +
          "    :libraryConstructionProtocol \"" + exp["design"]["library_construction_protocol"] + "\" ;\n" +
          "    :libraryLayout [\n" +
          "      a :" + exp["design"]["library_layout"]["type"] + " ;")
    if exp["design"]["library_layout"]["nominal_length"] != "":
        print("      :nominalLength " + exp["design"]["library_layout"]["nominal_length"] + " ;")
    if exp["design"]["library_layout"]["nominal_sdev"] != "":
        print("      :nominalSdev " + exp["design"]["library_layout"]["nominal_sdev"])
    print("    ]\n  ] .")


def print_prefixes():
    print("@prefix : <http://bio.cow/ontology/sra-experiement/> .")
    print("@prefix id: <http://identifiers.org/insdc.sra/> .")
    print("@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .")
    print("@prefix dct: <http://purl.obolibrary.org/obo/> .")
    print("")


def parse_xml(rootnode):
    lib_elems = ["LIBRARY_NAME",
                 "LIBRARY_CONSTRUCTION_PROTOCOL",
                 "LIBRARY_STRATEGY",
                 "LIBRARY_SELECTION",
                 "LIBRARY_SOURCE"]

    for node in rootnode:
        if node.tag == "EXPERIMENT":
            exp = {
                "id": "",
                "platform": "",
                "instrument_model": "",
                "design_description": "",
                "title": "",
                "design": {
                    "library_selection": "",
                    "library_source": "",
                    "library_layout": {
                        "type": "",
                        "nominal_length": "",
                        "nominal_sdev": "",
                    },
                    "library_construction_protocol": "",
                    "library_strategy": "",
                    "library_name": ""
                }
            }

            exp["id"] = node.attrib["accession"]
            for elem in node:
                if elem.tag == "TITLE":
                    if elem.text is None:
                        exp["title"] = ""
                    else:
                        exp["title"] = elem.text
                elif elem.tag == "DESIGN":
                    for dsn_elem in elem:
                        if dsn_elem.tag == "DESIGN_DESCRIPTION":
                            exp["design_description"] = dsn_elem.text
                            if exp["design_description"] is None:
                                exp["design_description"] = ""
                        elif dsn_elem.tag == "LIBRARY_DESCRIPTOR":
                            for ldesc_elem in dsn_elem:
                                if ldesc_elem.tag in lib_elems:
                                    if ldesc_elem.text is None:
                                        exp["design"][ldesc_elem.tag.lower()] = ""
                                    else:
                                        exp["design"][ldesc_elem.tag.lower()] = re.sub("\s", "_", ldesc_elem.text)
                                elif ldesc_elem.tag == "LIBRARY_LAYOUT":
                                    exp["design"]["library_layout"]["type"] = re.sub("\s", "_", ldesc_elem[0].tag)
                                    exp["design"]["library_layout"]["nominal_length"] = ldesc_elem[0].attrib.get("NOMINAL_LENGTH", "")
                                    exp["design"]["library_layout"]["nominal_sdev"] = ldesc_elem[0].attrib.get("NOMINAL_SDEV", "")

                elif elem.tag == "PLATFORM":
                    exp["platform"] = re.sub("\s", "_", elem[0].tag)
                    for plf_elem in elem[0]:
                        if plf_elem.tag == "INSTRUMENT_MODEL":
                            exp["instrument_model"] = re.sub("\s", "_", plf_elem.text)
            output_turtle(exp)


def main():
    parser = argparse.ArgumentParser(description="Generate a turtle from SRA experiement xml files.")
    parser.add_argument("xml_filepath", help="Path to a SRA experiement xml file.")
    parser.add_argument("-l", "--path_list", action="store_true",
                        help="If this is specified, the input file is interpreted as a text file listing paths to SRA experiement xml files. Each line specifies one path.")
    args = parser.parse_args()
    input_filepath = args.xml_filepath
    is_path_list = args.path_list

    with open(input_filepath, "r") as f:
        print_prefixes()
        if is_path_list:
            xml_path = f.readline().strip()
            while xml_path:
                xmldata = ET.parse(xml_path)
                rootnode = xmldata.getroot()
                parse_xml(rootnode)
                xml_path = f.readline().strip()
        else:
            xmldata = ET.parse(input_filepath)
            rootnode = xmldata.getroot()
            parse_xml(rootnode)


if __name__ == "__main__":
    main()
