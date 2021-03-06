library(dplyr)
library(ggplot2)
library(ggthemes)
library(RColorBrewer)


Diadata = read.csv(file = "diabetic_data.csv", stringsAsFactors = F)

# For Diadata1, fliter the data with missing race and gender
Diadata1 = Diadata[!((Diadata$race == "?")|(Diadata$gender == "Unknown/Invalid")), ]


ggplot(Diadata1,aes(age,fill = race))+
  geom_bar()+
  scale_color_discrete(h=c(0,360)+60)+
  ggtitle("Diabates distributions in age")


# For Diadata2, filter the data that each patient only has the first encounterID.

Diadata2 <- group_by(Diadata, patient_nbr) %>%
  dplyr::summarise(., encounter_id = min(encounter_id)) %>%
  left_join(.,Diadata, by = "encounter_id") %>%
  select(., -1) %>%
  rename(., patient_nbr = patient_nbr.y) %>%
  filter(., discharge_disposition_id %in% c(1:10,12,15:17,18,19:29))
#For Diadata3, we filter the Diadata2 and remove the patient who is dischaged to hospice.
#The dimension is 69980 * 50.


fac = function(i) {
  if (i %in% c(390:459,785))  return('Circulatory')
  else if (i %in% c(460:519,786)) return('Respiratory')
  else if (i %in% c(520:579,787)) return('Digestive')
  else if (i>=250.0&i<251) return('Diabetes')
  else if (i %in% (800:999)) return('Injury')
  else if (i %in% (710:739)) return('Musculoskeletal')
  else if (i %in% c(580:629,788)) return('Genitourinary')
  else if (i %in% c(140:239,780,781,784,790:799,240:249,251:279,680:709,782)) return('Neoplasms')
  else return('other')
} # the fac function is not a vector, need to Vectorize it.

Diadata2$diag_1 = as.numeric(Diadata2$diag_1) #convert diag_1 to numberic data.
Diadata2 = Diadata2[complete.cases(Diadata2),]


test=mutate(Diadata2,prim_diag=sapply(Diadata2$diag_1, fac)) 

test$prim_diag <- factor(test$prim_diag, 
                         levels = c("Circulatory","Respiratory","Neoplasms",
                                    "Digestive","other","Diabetes","Injury",
                                    "Musculoskeletal", "Genitourinary"))

count <- test %>%
  group_by(prim_diag) %>%
  summarise(.,count = n())
A=inner_join(test,count,by = 'prim_diag')

#####################################
ggplot(A, aes(x=reorder(prim_diag,count)))+
  geom_bar(fill="red3",size=1, width = 0.7)+
  coord_flip() +
  ggtitle("Primary Diagnosis in Final Dataset")+
  xlab("Primary Diagnosis") +
  theme(plot.title = element_text(lineheight=.8, face="bold"),
        axis.text=element_text(size=12),
        axis.title=element_text(size=14,face="bold"),
        panel.background = element_rect(fill = "white"),
        panel.grid.major = element_line(colour = "grey0",size = 0.1, linetype = 3),
        panel.grid.minor = element_blank())
#ggsave("Primary_Diagnosis.pdf") 
###########################################
####################################
# consider A1Cresult with Normal, None, and >8 . Filter away >8A1Cresult>7.
# create new column "new A1cresult" with factor of "Normal, None, High_medical change, High_medical not change.

rename_A1Cresult = function(i,j) {
  if (i == ">8" & j == "No")  return('High_medical not change')
  else if (i == ">8" & j == "Ch") return('High_medical change')
  else if(i==">7" & j == "No") return('Low_medical not change')
  else if (i == ">7" & j == "Ch") return('Low_medical change')
  else if(i == "Norm") return("Norm")
  else return('None')
}
exam <- filter(test, A1Cresult !=">7") %>%
  mutate(.,new_A1Cresult=mapply(rename_A1Cresult, .$A1Cresult,.$change)) 

#arrange the new_A1Cresult by ("None", "Norm", "High_medical change", "High_medical not change"):

exam$new_A1Cresult = factor(exam$new_A1Cresult, levels = c("None", "Norm", "High_medical change", "High_medical not change"))

test$max_glu_serum = factor(test$max_glu_serum, levels = c("None", "Norm",">200",">300"))
test$A1Cresult = factor(test$A1Cresult, levels = c("None", "Norm",">7",">8"))

# With all the case, including A1Crest !>"7". We find the result for A1Cresult is quite small and not a obvious difference.
#exam <- mutate(test,new_A1Cresult=mapply(rename_A1Cresult, test$A1Cresult,test$change)) 
################################################
ggplot(exam,aes(x=new_A1Cresult,y = num_medications))+
  geom_boxplot()+
  ylim(c(1,50))+
  facet_wrap(~prim_diag)+
  ggtitle("Patients' Medication Number VS HbA1C Test Results\n for Each Primary Diagnosis") +
  xlab("HbA1c Test")+
  ylab("Medication Number ")+
  scale_x_discrete(labels = c("None" = "None","Norm"="Normal",
                              "High_medical change" ="High\n Medical\nChange",
                              "High_medical not change" = "High\n Medical\n No Change")) +
  theme(legend.position = "none",
        axis.text = element_text(size = 7),
        plot.title = element_text(size=11, vjust = 2, face="bold"),
        axis.title = element_text(size=9,face="bold"),
        panel.margin = unit(0.1,"in"),
        strip.text = element_text(face = c("italic","bold"), size = 9, colour= "blue3")
  ) 


#ggsave("HbA1c_vs_numbermedication.pdf")

################################################
#calcute the ratio for readmittted for each case.

# count the number of each primary diagnosis:
count_A1C_primdiag <-  exam  %>%
  group_by(., new_A1Cresult, prim_diag)  %>%
  summarise(., total_A1C_primdiag = n())
# count the number of readmitted < 30days for each primary diagnosis:
count_A1C_primdiag_readmitted <-  exam  %>%
  group_by(., new_A1Cresult,prim_diag, readmitted)  %>%
  summarise(., total_A1C_primdiag_admitted30 = n()) %>%
  filter(., readmitted == "<30") %>%
  select(.,total_A1C_primdiag_admitted30)
# Generate a new data frame for ratio of readmitted people number vs each primary diagnosis people number:
ratio_readmitted <- inner_join(count_A1C_primdiag,count_A1C_primdiag_readmitted, by=c("new_A1Cresult","prim_diag")) %>%
  mutate(., ratio = total_A1C_primdiag_admitted30/total_A1C_primdiag)

# Plot the readmitted ratio for each promary diagnosis based on A1Cresult.

pp  <-   ggplot(ratio_readmitted, aes(x= new_A1Cresult, y=ratio,fill=new_A1Cresult)) +
  geom_bar(stat = "identity", width = 0.5)+
  facet_wrap(~ prim_diag)+
  ggtitle("Patients' Hospital Readmission Ratio Based on HbA1C Test Results\n for Each Primary Diagnosis") +
  xlab("HbA1c Test")+
  ylab("Readmitted Ratio")+
  scale_x_discrete(labels = c("None" = "None","Norm"="Normal",
                              "High_medical change" ="High\n Medical\nChange",
                              "High_medical not change" = "High\n Medical\n No Change")) +
  theme(legend.position = "none",
        axis.text = element_text(size = 7),
        plot.title = element_text(size=11, vjust = 2, face="bold"),
        axis.title = element_text(size=9,face="bold"),
        panel.margin = unit(0.1,"in"),
        strip.text = element_text(face = c("italic","bold"), size = 9, colour= "blue3")
  ) 

pp
#The plot suggests that the relationship between
#the probability of readmission and the HbA1c measurement 
#signicantly depends on the primary diagnosis 
#note that diabetes is always one of the secondary diagnoses

#ggsave("readmission ratio for HbA1C.pdf")

###############################################


ggplot(exam, aes(x=new_A1Cresult))+
  geom_bar(fill="green4",size=1, width = 0.7)+
  scale_x_discrete(labels = c("None" = "None","Norm"="Normal",
                              "High_medical change" ="High\n Medical\nChange",
                              "High_medical not change" = "High\n Medical\n No Change")) +
  xlab("HbA1C Test")+
  ylab("Population ") +
  ggtitle("HbA1C test")
theme(plot.title = element_text(lineheight=.8, face="bold"),
      axis.text=element_text(size=12),
      axis.title=element_text(size=14,face="bold"),
      panel.background = element_rect(fill = "white"),
      panel.grid.major = element_line(colour = "grey0",size = 0.1, linetype = 3),
      panel.grid.minor = element_blank())

ggsave("HbA1c test.png")

###############################################

medical_specialty_number <-  exam  %>%
  group_by(., medical_specialty)  %>%
  summarise(., total_medical_specialty = n())
# count the number of readmitted < 30days for each medical_specialty
medical_specialty_number_admitted30 <-  exam  %>%
  group_by(., medical_specialty, readmitted)  %>%
  summarise(., total_medical_specialty_admitted30 = n()) %>%
  filter(., readmitted == "<30") %>%
  select(.,total_medical_specialty_admitted30)
# Generate a new data frame for ratio of readmitted people number vs each medical_specialty:
exam1 <- inner_join(medical_specialty_number,medical_specialty_number_admitted30, by="medical_specialty") %>%
  filter(., medical_specialty != '?') %>%
  filter(., total_medical_specialty > 100) %>%
  mutate(., med_spec_readmitted_ratio_les30 = total_medical_specialty_admitted30/total_medical_specialty)

ggplot(exam1, aes(x= reorder(medical_specialty,med_spec_readmitted_ratio_les30), y=med_spec_readmitted_ratio_les30)) +
  geom_bar(stat = 'identity', fill = 'green4',size=2) +
  coord_flip() + 
  ggtitle("Patients' Hospital Readmission Ratio by Medical Specialty") +
  xlab("Medical Specialty")+
  ylab("Readmitted Ratio with 30 Days")+
  theme(legend.position = "none",
        axis.text = element_text(size = 10),
        plot.title = element_text(size= 12, vjust = 2, face="bold"),
        axis.title = element_text(size= 12),
        panel.margin = unit(0.1,"in"),
        strip.text = element_text(face = c("italic","bold"), size = 9, colour= "blue3")
  ) 

ggsave("medication VS readmitted ratio.png")
