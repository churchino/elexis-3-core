package ch.elexis.core.findings.migration;

import ch.elexis.core.findings.IFinding;

public interface IMigratorService {

	/**
	 * Migrate older information of the patient to the its new {@link IFinding}
	 * representation.
	 * 
	 * @param patientId
	 * @param filter
	 */
	public void migratePatientsFindings(String patientId, Class<? extends IFinding> filter);

	/**
	 * Migrate older information of the consultation to the its new
	 * {@link IFinding} representation.
	 * 
	 * @param consultationId
	 * @param filter
	 */
	public void migrateConsultationsFindings(String consultationId, Class<? extends IFinding> filter);
}
