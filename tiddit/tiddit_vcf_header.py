import pysam
import sys

def main(bam_header,library,sample_id,version):

	vcf_header=[]	

	vcf_header.append("##fileformat=VCFv4.1")
	vcf_header.append("##source=TIDDIT-" + version)

        #declare the events classified by TIDDIT

	vcf_header.append("##ALT=<ID=DEL,Description=\"Deletion\">")
	vcf_header.append("##ALT=<ID=DUP,Description=\"Duplication\">")
	vcf_header.append("##ALT=<ID=TDUP,Description=\"Tandem duplication\">")
	vcf_header.append("##ALT=<ID=INV,Description=\"Inversion\">")
	vcf_header.append("##ALT=<ID=INS,Description=\"Insertion\">")
	vcf_header.append("##ALT=<ID=BND,Description=\"Break end\">")

	#print chromosomes and length
	for contig in bam_header["SQ"]:
		#print(contig)
		vcf_header.append("##contig=<ID={},length={}>".format(contig["SN"],contig["LN"]) )

	#declare the info field

	vcf_header.append("##INFO=<ID=SVTYPE,Number=1,Type=String,Description=\"Type of structural variant\">")
	vcf_header.append("##INFO=<ID=END,Number=1,Type=Integer,Description=\"End of an intra-chromosomal variant\">")
	vcf_header.append("##INFO=<ID=SVLEN,Number=.,Type=Integer,Description=\"Difference in length between REF and ALT alleles\">")
	vcf_header.append("##INFO=<ID=LFA,Number=1,Type=Integer,Description=\"Links from window A\">")
	vcf_header.append("##INFO=<ID=LFB,Number=1,Type=Integer,Description=\"Links from window B\">")
	vcf_header.append("##INFO=<ID=LTE,Number=1,Type=Integer,Description=\"Links to event\">")
	vcf_header.append("##INFO=<ID=COVA,Number=1,Type=Float,Description=\"Coverage on window A\">")
	vcf_header.append("##INFO=<ID=COVM,Number=1,Type=Float,Description=\"The coverage between A and B\">")
	vcf_header.append("##INFO=<ID=COVB,Number=1,Type=Float,Description=\"Coverage on window B\">")
	vcf_header.append("##INFO=<ID=OR,Number=4,Type=Integer,Description=\"Orientation of the pairs (FF,RR,RF,FR)\">")
	vcf_header.append("##INFO=<ID=ORSR,Number=2,Type=Integer,Description=\"Orientation of the split reads (inverted,normal)\">")
	vcf_header.append("##INFO=<ID=CIPOS,Number=2,Type=Integer,Description=\"Confidence interval around POS for imprecise variants\">")
	vcf_header.append("##INFO=<ID=CIEND,Number=2,Type=Integer,Description=\"Confidence interval around END for imprecise variants\">")
	vcf_header.append("##INFO=<ID=QUALA,Number=1,Type=Float,Description=\"The average mapping quality of the reads in window A\">")
	vcf_header.append("##INFO=<ID=QUALB,Number=1,Type=Float,Description=\"The average mapping quality of the reads in window B\">")

	#Declare the filters

	vcf_header.append("##FILTER=<ID=BelowExpectedLinks,Description=\"The number of links or reads between A and B is too small\">")
	vcf_header.append("##FILTER=<ID=FewLinks,Description=\"Unexpectedly low fraction of discordant reads betwen A and B\">")
	vcf_header.append("##FILTER=<ID=UnexpectedCoverage,Description=\"The coverage of the window on chromosome B or A is higher than 4*average coverage\">")
	vcf_header.append("##FILTER=<ID=Smear,Description=\"Window A and Window B overlap\">")
	vcf_header.append("##FILTER=<ID=RegionalQ,Description=\"The mapping quality of the region is lower than the user set limit\">")
	vcf_header.append("##FILTER=<ID=MinSize,Description=\"The variant is smaller than the user set limit\">")
	vcf_header.append("##FILTER=<ID=Ploidy,Description=\"Intrachromosomal variant on a chromosome having 0 ploidy\">")
	vcf_header.append("##FILTER=<ID=SplitsVSDiscs,Description=\"large variant supported mainly by split reads (and not discorant pairs) \">")
	vcf_header.append("##FILTER=<ID=Density,Description=\"The discordant reads cluster too tightly\">")

	#set format

	vcf_header.append("##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">")
	vcf_header.append("##FORMAT=<ID=CN,Number=1,Type=Integer,Description=\"Copy number genotype for imprecise events\">")
	vcf_header.append("##FORMAT=<ID=DV,Number=1,Type=Integer,Description=\"Number of paired-ends that support the event\">")
	vcf_header.append("##FORMAT=<ID=RV,Number=1,Type=Integer,Description=\"Number of split reads that support the event\">")
	vcf_header.append("##FORMAT=<ID=DR,Number=2,Type=Integer,Description=\"Number of paired-ends that supporting the reference allele (breakpoint A, and B)\">")
	vcf_header.append("##FORMAT=<ID=RR,Number=2,Type=Integer,Description=\"Number of reads supporting the reference allele (breakpoint A, and B)\">")


	#library statistics line
	vcf_header.append("##LibraryStats=TIDDIT-{} Coverage={}  ReadLength={} MeanInsertSize={} STDInsertSize={} Reverse_Forward={}".format(version,library["avg_coverage"],library["avg_read_length"],library["avg_insert_size"],library["std_insert_size"],library["mp"] ) ) 

	#command used to launch tiddit
	vcf_header.append("##TIDDITcmd=\"" + " ".join(sys.argv) + "\"")

	vcf_header.append("#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t"+sample_id)
	return("\n".join(vcf_header))


#generate test header
#bam_file_name=sys.argv[1]

#samfile = pysam.AlignmentFile(bam_file_name, "r")
#bam_header=samfile.header
#samfile.close()

#try:
#	sample_id=header["RG"][0]["SM"]
#
#except:
#	sample_id=bam_file_name.split("/")[-1].split(".")[0]

#library={}
#version="4.0.0"

#library["avg_read_length"]=151
#library["avg_insert_size"]=350
#library["std_insert_size"]=400
#library["mp"]=True
#library["avg_coverage"]=35


#print(main(bam_header,library,sample_id,version))

