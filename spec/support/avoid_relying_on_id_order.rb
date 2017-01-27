# Ensures that entries are not returned ordered by the id field by
# default. Breaks the tests (deliberately) unless we order by id
# explicitly. In postgres the order is random unless specified.
class VCAP::CloudController::Process
  set_dataset dataset.order(:"#{VCAP::CloudController::Process.table_name}__guid")
end
