package ch.elexis.core.ui.commands;

import java.util.ArrayList;
import java.util.List;

import org.eclipse.core.commands.AbstractHandler;
import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.ui.IWorkbenchPage;
import org.eclipse.ui.PlatformUI;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import ch.elexis.core.ui.util.SWTHelper;
import ch.elexis.core.ui.views.FallDetailView;
import ch.elexis.data.Fall;
import ch.elexis.data.Konsultation;
import ch.elexis.data.Patient;

public class FallCopyCommand extends AbstractHandler {
	private static Logger logger = LoggerFactory.getLogger(FallCopyCommand.class);
	
	@Override
	public Object execute(ExecutionEvent event) throws ExecutionException{
		IWorkbenchPage activePage =
			PlatformUI.getWorkbench().getActiveWorkbenchWindow().getActivePage();
		FallDetailView fallDetailView = (FallDetailView) activePage.findView(FallDetailView.ID);
		Fall activeFall = fallDetailView.getActiveFall();
		if (activeFall == null)
			return null;
		Fall clone = createFallClone(activeFall);
		
		// only ask for consultation transfer if case is still open 
		if (activeFall.isOpen()) {
			Konsultation[] consultations = activeFall.getBehandlungen(true);
			if (consultations != null && consultations.length > 0) {
				boolean transferCons =
					SWTHelper.askYesNo(Messages.FallCopyCommand_RelatedConsultations,
						Messages.FallCopyCommand_TransferConsultations
							+ Messages.FallCopyCommand_AttentionTransferConsultations);
				if (transferCons) {
					logger.debug("trying to transfer consulations");
					for (Konsultation cons : consultations) {
						if (cons.isEditable(false)) {
							cons.setFall(clone);
						}
					}
				}
			}
		}
		return null;
	}
	
	private Fall createFallClone(Fall fall){
		Patient pat = fall.getPatient();
		Fall clone =
			pat.neuerFall(fall.getBezeichnung(), fall.getGrund(), fall.getAbrechnungsSystem());
		
		String[] fields =
			new String[] {
				Fall.FLD_GARANT_ID, Fall.FLD_FALL_NUMMER, Fall.FLD_RN_PLANUNG, Fall.FLD_RES,
				Fall.FLD_DATUM_VON, Fall.FLD_EXTINFO, Fall.FLD_XGESETZ
			};
		String[] values =
			new String[] {
				fall.getGarant().getId(), fall.getFallNummer(), fall.get(Fall.FLD_RN_PLANUNG),
				fall.get(Fall.FLD_RES), fall.getBeginnDatum(), fall.get(Fall.FLD_EXTINFO),
				fall.getAbrechnungsSystem()
			};
		clone.set(fields, values);
		clone = copyFields(fall, clone);
		
		return clone;
	}
	
	private Fall copyFields(Fall fall, Fall clone){
		// copy required fields
		List<String> keys = loadFieldKeys(fall.getRequirements());
		for (String key : keys) {
			clone.setInfoString(key, fall.getRequiredString(key));
		}
		
		// copy optional fields
		keys = loadFieldKeys(fall.getOptionals());
		for (String key : keys) {
			clone.setInfoString(key, fall.getInfoString(key));
		}
		return clone;
	}
	
	private List<String> loadFieldKeys(String fieldString){
		List<String> keys = new ArrayList<String>();
		String[] fields = fieldString.split(";");
		for (String field : fields) {
			String[] nameType = field.split(":");
			keys.add(nameType[0]);
		}
		return keys;
	}
}
