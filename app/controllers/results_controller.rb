class ResultsController < ApplicationController
    before_action :logged_in_user, only: [:new]
    
    def new
        @result = Result.new
        @algorithms = Algorithm.where(user_id: current_user.id)
        puts @algorithms
    end

    def create
        current_algorithm = Algorithm.find(params[:result][:algorithm_id])
        @result = current_algorithm.results.build(result_params)
        validResult = @result.valid?
        unless ((params[:result][:dice].present?) || (params[:result][:hausdorff].present?))
            @result.errors.add :base, "You must choose at least one validation method"
        end
        unless params[:result][:file].present?
            @result.errors.add :file, "Must supply a segmentation file"
        end
        if @result.errors.any?
            @dataset = Dataset.find_by_id(@result.dataset_id)
            @algorithms = Algorithm.where(user_id: current_user.id)
            render :template => 'datasets/show'
        elsif @result.save
            # Write the segmentation file to result directory
            uploaded_file = params[:result][:file]
            filename = uploaded_file.original_filename
            dir_path = Rails.root.join('public/uploads/result/',current_user.id.to_s,@result.id.to_s)
            FileUtils.mkdir_p(dir_path) unless File.directory?(dir_path)
            file_path = Rails.root.join(dir_path,filename)
            File.open(file_path, 'wb') do |file|
                file.write(uploaded_file.read)
            end

            dataset = Dataset.find_by_id(@result.dataset_id)
            results_file_path = dir_path.join('results.txt')
            ground_truth_path = Rails.root.join('public','uploads','dataset',dataset.user_id.to_s,dataset.id.to_s,dataset.ground_truth.to_s).to_s
            system("touch #{results_file_path}")

            # Compute hausdorff distance metric if requested
            if params[:result][:hausdorff].present?
                puts "********** RUNNING ComputeHausdorff **************"
                cmd = Rails.root.join("scripts/hausdorff/bin/ComputeHausdorff #{file_path} #{ground_truth_path} #{results_file_path}").to_s
                hausdorff_result = system(cmd)
                puts "*********** #{hausdorff_result.to_s} **************"
            end

            # Compute dice coefficient metric if requested
            if params[:result][:dice].present?
                puts "********** RUNNING ComputeDiceCoefficient **************"
                cmd = Rails.root.join("scripts/dice_coefficient/bin/ComputeDiceCoefficient #{file_path} #{ground_truth_path} #{results_file_path}").to_s
                dice_coefficient_result = system(cmd)
                puts "*********** #{dice_coefficient_result.to_s} **************"
            end

            # Update results with the metrics which were run
            # TODO: parse results file and update results object and save
            
            # Go to new result
            redirect_to @result
        else
            render 'new'
        end
    end

    def show
        @result = Result.find(params[:id])
    end

    private

    def result_params
        permitted = params.require(:result).permit(:algorithm_id, :hausdorff, :dice, :dataset_id)
    end
end
