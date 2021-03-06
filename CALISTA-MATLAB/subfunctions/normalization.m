function [DATA]=normalization(data_type,format_data,perczeros_genes,perczeros_cells,cut_variable_genes,cells_2_cut)

[FileName,PathName,FilterIndex] = uigetfile('*.*');
filename=strcat(PathName, FileName);
imported_data=importdata(filename);

DATA.FileName=FileName;
switch format_data
    case 1
        NUM=imported_data.data;
        NUM(isnan(NUM(:,1)),:)=[]; % REMOVE ROW WITH AT LEAST ONE NaN
        totDATA=NUM(:,1:end-1);
        timeline=NUM(:,end);
        %         [totDATA,timeline,outlier_idx,outliers]=remove_outliers(totDATA,timeline);
        TXT=imported_data.textdata;
        DATA.genes=TXT(1,1:end-1);
    case 2
        NUM=[imported_data.data(2:end,:)' imported_data.data(1,:)'];
        NUM(isnan(NUM(:,1)),:)=[]; % REMOVE ROW WITH AT LEAST ONE NaN
        totDATA=NUM(:,1:end-1);
        timeline=NUM(:,end);
        TXT=imported_data.textdata';
        DATA.genes=TXT(1,2:end);
    case 3
        NUM=imported_data.data;
        NUM(isnan(NUM(:,1)),:)=[]; % REMOVE ROW WITH AT LEAST ONE NaN
        totDATA=NUM;
        timeline=zeros(size(NUM,1),1);
        TXT=imported_data.textdata;
        if length(TXT(1,:))>size(totDATA,2)
            DATA.genes=TXT(1,2:end);
        else
            DATA.genes=TXT(1,:);
        end
    case 4
        NUM=imported_data.data';
        NUM(isnan(NUM(:,1)),:)=[]; % REMOVE ROW WITH AT LEAST ONE NaN
        totDATA=NUM;
        timeline=zeros(size(NUM,1),1);
        TXT=imported_data.textdata';
        if length(TXT(1,:))>size(totDATA,2)
            DATA.genes=TXT(1,2:end);
        else
            DATA.genes=TXT(1,:);
        end
    case 5
        fprintf(' Text data extracted preview: \n\n')
        disp(imported_data.textdata(1:5,1:7))
        [row,col]=size(imported_data.textdata)
        
        fprintf(' Expression data extracted preview: \n\n')
        disp(imported_data.data(1:5,1:10))
        [row,col]=size(imported_data.data)
        
        rows= input(' * Key starting and ending rows for the expression values (e.g. [1 405]): ');
        cols= input(' * Key starting and ending columns for the expression values (e.g. [2 22525]): ');
        genes_vector=input(' * Press 1 if columns=genes, 0 otherwise: ');
        
        NUM=imported_data.data;
        TXT=imported_data.textdata;
        
        
        %         NUM(isnan(NUM(:,1)),:)=[]; % REMOVE ROW WITH AT LEAST ONE NaN
        totDATA=NUM(rows(1):rows(2),cols(1):cols(2));
        if genes_vector
            cols= input(' * Key starting and ending columns for gene names (e.g. [6 22529]): ');
            DATA.genes=TXT(1,cols(1):cols(2));
        else
            rows= input(' * Key starting and ending rows for gene names (e.g. [6 22529]): ');
            totDATA=totDATA';
            DATA.genes=TXT(rows(1):rows(2),1);
        end
        
        time_info=input(' * Add time info (1-Yes, 0-No): ');
        
        if time_info
            time_vector=input(' * Key the column or row vector (e.g 1) of the EXPRESSION DATA MATRIX with time / cell stage info: ');
            if genes_vector
                timeline=NUM(rows(1):rows(2),time_vector);
            else
                timeline=NUM(time_vector,cols(1):cols(2));
            end
        else
            timeline=zeros(size(totDATA,1),1);
        end
        %         [totDATA,timeline,outlier_idx,outliers]=remove_outliers(totDATA,timeline);
        
end


if cells_2_cut==1
    fprintf('\n\n**** Select the csv file containing cell indices to remove ****\n\n')
    [FileName,PathName,FilterIndex] = uigetfile('*.*');
    filename2=strcat(PathName, FileName);
    cells_2_cut = csvread(filename2);
    timeline(cells_2_cut)=[];
    totDATA(cells_2_cut,:)=[];
end

%% Cut first genes and cells with high % of zeros
if data_type==1
    totDATA(totDATA>28)=28; %ct max
    zeros_genes=sum(totDATA==max(max(totDATA)))*100/size(totDATA,1);
    zeros_cells=sum(totDATA==max(max(totDATA)),2)*100/size(totDATA,2);
    
else
    zeros_genes=sum(totDATA==0)*100/size(totDATA,1);
    zeros_cells=sum(totDATA==0,2)*100/size(totDATA,2);
end
% figure
% bar(sort(zeros_genes))
%more than 90%
% CUTTING genes
idx2cut=find(zeros_genes>=perczeros_genes);
totDATA(:,idx2cut)=[];
DATA.genes(idx2cut)=[];
DATA.cut_sort.idx2cutGENES=idx2cut;
% CUTTING cells
% figure
% bar(sort(zeros_cells))
idx2cut=find(zeros_cells>=perczeros_cells);
totDATA(idx2cut,:)=[];
DATA.cut_sort.idx2cutCELL=idx2cut;


%% Most variable genes
if data_type>=1
    SD=std(totDATA);
    MEAN=sum(totDATA, 1) ./ sum(totDATA~=0, 1);%mean(nonzeros(totDATA));%nanmean(totDATA);
    CV=(SD.^2)./MEAN;
    
    % Remove genes with CV=NaN
    [nanCV] = find(isnan(CV));
    
    CV(nanCV)=[];
    MEAN(nanCV)=[];
    SD(nanCV)=[];
    totDATA(:,nanCV)=[];
    genes=DATA.genes;
    genes(nanCV)=[];
    DATA.genes=genes;
    % figure
    % plot(MEAN,log(CV),'*')
    % xlabel('Mean Expression')
    % ylabel('Log CV')
    
    % Binning
    % 'fd'   The Freedman-Diaconis rule is less sensitive to
    % outliers in the data, and may be more suitable
    % for data with heavy-tailed distributions. It
    %     uses a bin width of 2*IQR(X(:))*NUMEL(X)^(-1/3),
    %     where IQR is the interquartile range.
    nbin=20;
    [~,~,BIN]=histcounts(MEAN,nbin);%,'BinMethod','fd');
    z_scoredCV=[];
    most_variable_genes_idx=[];
    zscores_most_variable_genes=[];
    for i=1:nbin
        if length(find(BIN==i))>0
            idx_genes_each_bin{i}=find(BIN==i);
            z_scored_CV{i}=zscore(CV(idx_genes_each_bin{i}));
%             temp_genes=idx_genes_each_bin{i}(find(abs(z_scored_CV{i})>=cut_variable_genes));
            most_variable_genes_idx=[most_variable_genes_idx idx_genes_each_bin{i}];
%             temp_zscores=z_scored_CV{i}(find(abs(z_scored_CV{i})>=cut_variable_genes));
            zscores_most_variable_genes=[zscores_most_variable_genes z_scored_CV{i}];
        end
    end
    [aaa,idx] = sort(abs(zscores_most_variable_genes),'descend');
    zscores_most_variable_genes = zscores_most_variable_genes(idx);
    most_variable_genes=genes(most_variable_genes_idx);
    most_variable_genes=most_variable_genes(idx);
    totDATA=totDATA(:,most_variable_genes_idx);
    totDATA=totDATA(:,idx);
    DATA.genes=most_variable_genes;
    DATA.zscores_most_variable_genes=zscores_most_variable_genes;
end

% Normalization to max mRNA=200
switch data_type
    case 1
        log_max_mRNA=log2(200);
        if min(min(totDATA))<0
            totDATA=totDATA-min(min(totDATA)); % shift to ct min = 0
        end
        totDATA(totDATA>28)=28; %ct max
        ctmax=max(max(totDATA));
        log2Ex=ctmax-totDATA;
        base=2^(log_max_mRNA/max(max(log2Ex)));
        totDATA=round(base.^log2Ex)-1;
        % % %     exponent=log_max_mRNA*(log2Ex./repmat(max(log2Ex),size(log2Ex,1),1));
        % % %     totDATA=round(2.^exponent)-1;
    case 2
        totDATA=log2(totDATA+1);
        log_max_mRNA=log2(200);
        totDATA(totDATA>28)=28; %ct max
        if min(min(totDATA))<0
            totDATA=totDATA-min(min(totDATA)); % shift to ct min = 0
        end
        ctmax=max(max(totDATA));
        log2Ex=totDATA;
        %     base=2^(log_max_mRNA/max(max(log2Ex)));
        %     totDATA=round(base.^log2Ex);
        exponent=log_max_mRNA*(log2Ex./repmat(max(log2Ex),size(log2Ex,1),1));
        totDATA=round(2.^exponent)-1;
    case 3
        totDATA=log2(totDATA+1);
        log_max_mRNA=log2(200);
        totDATA(totDATA>28)=28; %ct max
        if min(min(totDATA))<0
            totDATA=totDATA-min(min(totDATA)); % shift to ct min = 0
        end
        ctmax=max(max(totDATA));
        log2Ex=totDATA;
        %     base=2^(log_max_mRNA/max(max(log2Ex)));
        %     totDATA=round(base.^log2Ex);
        exponent=log_max_mRNA*(log2Ex./repmat(max(log2Ex),size(log2Ex,1),1));
        totDATA=round(2.^exponent)-1;
    case 4
        totDATA=log2(log2(totDATA+1)+1);
        log_max_mRNA=log2(200);
        totDATA(totDATA>28)=28; %ct max
        if min(min(totDATA))<0
            totDATA=totDATA-min(min(totDATA)); % shift to ct min = 0
        end
        ctmax=max(max(totDATA));
        log2Ex=totDATA;
        %     base=2^(log_max_mRNA/max(max(log2Ex)));
        %     totDATA=round(base.^log2Ex);
        exponent=log_max_mRNA*(log2Ex./repmat(max(log2Ex),size(log2Ex,1),1));
        totDATA=round(2.^exponent)-1;
        
end

% %% CUTTING genes
% zeros_genes=sum(totDATA==0)*100/size(totDATA,1);
% % figure
% % bar(sort(zeros_genes))
% %more than 90%
% idx2cut=find(zeros_genes>=perczeros_genes);
% if length(idx2cut)>=1
%     fprintf('%4i %s',length(idx2cut),' gene(s) removed')
%     fprintf('\n')
%     DATA.cut_sort.gene_removed=DATA.genes(idx2cut);
% end
% DATA.cut_sort.idx2cutGENES=idx2cut;
% totDATA(:,idx2cut)=[];
% DATA.genes(idx2cut)=[];
% 
% %% CUTTING cells
% zeros_cells=sum(totDATA==0,2)*100/size(totDATA,2);
% % figure
% % bar(sort(zeros_cells))
% idx2cut=find(zeros_cells>=perczeros_cells);
% totDATA(idx2cut,:)=[];
% 
% if length(idx2cut)>=1
%     fprintf('%4i %s',length(idx2cut),' cell(s) removed')
%     fprintf('\n')
%     timeline(idx2cut)=[];
% end
% DATA.cut_sort.idx2cutCELL=idx2cut;
% %%

DATA.timeline=timeline;
DATA.time=unique(timeline);
DATA.num_time_points=length(DATA.time);
sortTOTdata=[];
sortTIMELINE=[];
idx_sorted_cells=[];
for k=1:DATA.num_time_points
    I=find(timeline==DATA.time(k));
    idx_sorted_cells=[idx_sorted_cells; I];
    cutDIMENSION(k)=length(I);
    sortTOTdata=[sortTOTdata; totDATA(I,:)];
    sortTIMELINE=[sortTIMELINE; timeline(I)];
end
DATA.cut_sort.idx_sorted_cells=idx_sorted_cells;
DATA.totDATA=sortTOTdata;
DATA.timeline=sortTIMELINE;
%%%%%%%%
DATA.totDATA(isnan(totDATA)) = 0 ;
%%%%%%%%
[DATA.nvars,DATA.numGENES]=size(DATA.totDATA);

data= mat2cell(DATA.totDATA',DATA.numGENES,cutDIMENSION);% now rows=genes and columns=cells
DATA.singleCELLdata=data;
DATA.imported_data=imported_data;
end