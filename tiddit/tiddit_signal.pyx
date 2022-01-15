import pysam
import sys
import os
import itertools
import tiddit_coverage
import time

def find_SA_query_range(SA):
	a =pysam.AlignedSegment()

	if SA[2] == "+":
		a.flag = 64
	else:
		a.flag = 80

	cdef list SA_cigar=[]
	SC = ["".join(x) for _, x in itertools.groupby(SA[3], key=str.isdigit)]		

	cdef dict s_to_op={"M":0,"S":4,"H":5,"D":2,"I":1}
	for i in range(0,int(len(SC)/2)):
		op=s_to_op[SC[i*2+1]]
		SA_cigar.append( (op,int(SC[i*2])) )

	a.cigar = tuple(SA_cigar)
	return(a.query_alignment_start,a.query_alignment_end)

def SA_analysis(read,min_q,splits,tag):
	#print(read.query_alignment_start,read.query_alignment_end,read.is_reverse,read.cigarstring)
	suplementary_alignments=read.get_tag(tag).rstrip(";").split(";")
	
	if len(suplementary_alignments) > 1:
		return(splits)

	SA_data=suplementary_alignments[0].split(",")
	SA_pos=int(SA_data[1])

	if int(SA_data[4]) < min_q:
		return(splits)

	SA_query_alignment_start,SA_query_alingment_end=find_SA_query_range(SA_data)
	SA_chr=SA_data[0]


	SA_split_pos=SA_pos
	split_pos=read.reference_end
	if SA_chr < read.reference_name:
		chrA=SA_chr
		chrB=read.reference_name
		SA_split_pos=read.reference_end
		split_pos=SA_pos

	else:
		chrA=read.reference_name
		chrB=SA_chr

		if chrA == chrB:
			if SA_split_pos < split_pos:
				SA_split_pos=read.reference_end
				split_pos=SA_pos

	if not chrA in splits:
		splits[chrA]={}

	if not chrB in splits[chrA]:
		splits[chrA][chrB]={}

	if not read.query_name in splits[chrA][chrB]:
		splits[chrA][chrB][read.query_name]=[]

	if "-" == SA_data[2]:
		splits[chrA][chrB][read.query_name]+=[split_pos,read.is_reverse,SA_split_pos,True]
	else:
		splits[chrA][chrB][read.query_name]+=[split_pos,read.is_reverse,SA_split_pos,False]

	return(splits)

def main(str bam_file_name,str prefix,int min_q,int max_ins,str sample_id):

	samfile = pysam.AlignmentFile(bam_file_name, "r")
	bam_header=samfile.header
	cdef int bin_size=50
	cdef str file_type="wig"
	cdef str outfile=prefix+".tiddit_coverage.wig"

	t_update=0
	t_split=0
	t_disc=0
	t_tot=0

	coverage_data,end_bin_size=tiddit_coverage.create_coverage(bam_header,bin_size)	

	cdef dict data={}
	cdef dict splits={}
	cdef dict clips={}

	for chrA in bam_header["SQ"]:

		clips[chrA["SN"]]=[]
		for chrB in bam_header["SQ"]:
			if chrA["SN"] <= chrB["SN"]:
				if not chrA["SN"] in data:
					data[chrA["SN"]] = {}
					splits[chrA["SN"]] = {}
				data[chrA["SN"]][chrB["SN"]]={}
				splits[chrA["SN"]][chrB["SN"]]={}


	chromosome_set=set([])
	chromosomes=[]

	clip_dist=100

	t_tot=time.time()
	#f=open("{}_tiddit/clipped_{}.fa".format(prefix,sample_id),"w")
	for read in samfile.fetch(until_eof=True):

		if read.is_unmapped or read.is_duplicate:
			continue

		t=time.time()
		if read.mapq >= min_q:
			coverage_data[read.reference_name]=tiddit_coverage.update_coverage(read,bin_size,coverage_data[read.reference_name],min_q,end_bin_size[read.reference_name])
		t_update+=time.time()-t

		if not read.reference_name in chromosome_set:
			print("Collecting signals on contig: {}".format(read.reference_name))
			chromosome_set.add(read.reference_name)
			chromosomes.append(read.reference_name)

		t=time.time()

		if read.has_tag("SA") and not (read.is_supplementary or read.is_secondary) and read.mapq >= min_q:
			splits=SA_analysis(read,min_q,splits,"SA")

		if not (read.is_supplementary or read.is_secondary) and read.mapq > 1:
			if (read.cigartuples[0][0] == 4 and read.cigartuples[0][1] > 10) and (read.cigartuples[-1][0] == 0 and read.cigartuples[-1][1] > 30) and len(read.cigartuples) < 7:
				#if not read.reference_name in clips:
				#	clips[read.reference_name]=[[],[]]
				clips[read.reference_name].append([">{}|{}\n".format(read.query_name,read.reference_start),read.query_sequence+"\n"])
				#clips[read.reference_name][1].append([read.reference_start,0])

			elif read.cigartuples[-1][0] == 4 and read.cigartuples[-1][1] > 10 and (read.cigartuples[0][0] == 0 and read.cigartuples[0][1] > 30) and len(read.cigartuples) < 7:
				#if not read.reference_name in clips:
				#	clips[read.reference_name]=[[],[]]
				clips[read.reference_name].append([">{}|{}\n".format(read.query_name,read.reference_start),read.query_sequence+"\n"])
				#clips[read.reference_name][1].append([read.reference_start,0])

		t_split+=time.time()-t

		t=time.time()
		if ( abs(read.isize) > max_ins or read.next_reference_name != read.reference_name ) and read.mapq >= min_q:

			if read.next_reference_name < read.reference_name:
				chrA=read.next_reference_name
				chrB=read.reference_name
			else:
				chrA=read.reference_name
				chrB=read.next_reference_name

			if not read.query_name in data[chrA][chrB]:
				data[chrA][chrB][read.query_name]=[]

			data[chrA][chrB][read.query_name].extend((read.reference_start,read.reference_end,read.is_reverse))
		t_disc+=time.time()-t

	print("total",time.time()-t_tot)
	print("coverage",t_update)
	print("split",t_split)
	print("disc",t_disc)

	#print("writing coverage wig")
	#tiddit_coverage.print_coverage(coverage_data,bam_header,bin_size,file_type,outfile)

	print("Writing signals to file")

	for chrA in data:
		for chrB in data[chrA]:
			f=open("{}_tiddit/discordants_{}_{}_{}.tab".format(prefix,sample_id,chrA,chrB),"w")

			for fragment in data[chrA][chrB]:
				if len(data[chrA][chrB][fragment]) < 4:
					continue

				f.write("{}\t{}\n".format(fragment,"\t".join(map(str, data[chrA][chrB][fragment] )))  )

			f.close()

	for chrA in splits:
		for chrB in splits[chrA]:

			f=open("{}_tiddit/splits_{}_{}_{}.tab".format(prefix,sample_id,chrA,chrB),"w")
			for fragment in splits[chrA][chrB]:
				f.write("{}\t{}\n".format(fragment,"\t".join(map(str, splits[chrA][chrB][fragment] )))  )

			f.close()

	for chrA in clips:
		f=open("{}_tiddit/clips_{}_{}.fa".format(prefix,sample_id,chrA),"w")
		for clip in clips[chrA]:
			f.write("".join( clip ))
		f.close()

	return(coverage_data)
	#return(coverage_data,clips)
	#return(coverage_data,clips)
