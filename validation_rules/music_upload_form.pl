{
    # Fields for validating
    fields => [ qw/upload_type filename title category_id rating_id stage_id 
                privacy copyright_year agree_to_rules/ ],
    filters => [
        qr/.+/        => filter(qw/trim strip/),    
    ],
    checks => [
        upload_type    => is_required("There was an error recognizing what type of upload you're doing."),
        filename       => is_required("You must select a file to upload."),
        title          => is_required("A Title is required."),
        category_id    => is_required("A Category is required."),
        rating_id      => is_required("A Rating is required."),
        stage_id       => is_required("A Stage is required."),
        privacy        => is_required("You must set a Privacy setting."),
        agree_to_rules => is_required("You must check that you have read and agree to the site rules."),

        title => is_long_at_most( 255, 'Your Title should be no more than 255 characters.' ),
    ],
}
